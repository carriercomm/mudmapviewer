//
//  MapView.swift
//  MudMapViewer
//
//  Created by Wil Hunt on 11/22/15.
//  Copyright © 2015 William Hunt. All rights reserved.
//

import Foundation
import AppKit

class MapView : NSView
{
    let _currentRoomId: Int64 = 1170
    
    var _currentRoom: MapRoom?
    var _centerLocation: Coordinate3D<Int64>?
    var _zLevel: Int64?
    
    var _rooms = [Int64: MapRoom]()
    
    var _zoom: CGFloat = 10
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        asyncLoadMapElements()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        asyncLoadMapElements()
    }
    
    func asyncLoadMapElements() {
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            
            let rooms = self.loadMapElements()
            dispatch_async(dispatch_get_main_queue()) {
                self._rooms = rooms
                self.setNeedsDisplayInRect(self.bounds)
            }
        }
    }
    
    func loadMapElements() -> [Int64: MapRoom] {
        var zoneRooms = [Int64: MapRoom]()
        do {
            let db = try MapDb()
            _currentRoom = db.getRoomById(_currentRoomId)
            if let centerRoom = _currentRoom {
                zoneRooms = db.getRoomsByZoneId(centerRoom.zoneId)
            }
        } catch {
            Swift.print("Error loading database.")
        }
        return zoneRooms
    }
    
    override func mouseDown(theEvent: NSEvent) {
        Swift.print(theEvent)
        let z: Int64
        if let center = centerLocation {
            z = center.z
        } else {
            z = 0
        }
        if let newLoc = map2DCoordsFromWindowCoords(theEvent.locationInWindow) {
            _centerLocation = Coordinate3D<Int64>(x: Int64(newLoc.x), y: Int64(newLoc.y), z: z)
            _currentRoom = nil
        }

        self.setNeedsDisplayInRect(bounds)
        
    }
    
    func map2DCoordsFromWindowCoords(loc: NSPoint) -> NSPoint? {
        if let center = centerLocation {
            let x = (loc.x - self.bounds.midX) * _zoom + CGFloat(center.x)
            let y = (loc.y - self.bounds.midY) * _zoom + CGFloat(center.y)
            let map2DCoords = NSPoint(x: x, y: y)
            
            return map2DCoords
        }
        return nil
    }
    
    func windowCoordsFromMap2DCoords(loc: NSPoint) -> NSPoint? {
        if let center = centerLocation {
            let dx = (loc.x - CGFloat(center.x))
            let dy = -(loc.y - CGFloat(center.y))
            
            let x: CGFloat = self.bounds.midX + dx / _zoom
            let y: CGFloat = self.bounds.midY + dy / _zoom
            return NSPoint(x: x, y: y)
        }
        return nil
    }
    
    override func drawRect(dirtyRect: NSRect) {
        do {
            let db = try MapDb()
            _currentRoom = db.getRoomById(_currentRoomId)
            if let center = centerLocation {
                for (_, room) in _rooms {
                    if (center.z == room.location.z) {
                        for exit in room.exits {
                            drawExit(exit, rect: dirtyRect)
                        }
                    }
                }
                
                for (_, room) in _rooms {
                    drawRoom(room, rect: dirtyRect)
                }
                
                markCurrentRoom()
            }
        } catch {
            Swift.print("Error loading database.")
        }
    }
    
    var centerLocation: Coordinate3D<Int64>? {
        if (_centerLocation == nil) {
            if let currentRoom = _currentRoom {
                _centerLocation = currentRoom.location
            }
        }
        return _centerLocation
    }
    
    func roomDrawLocation(room: MapRoom) -> NSPoint? {
        let windowCoords = windowCoordsFromMap2DCoords(room.locationAsPoint)
        return windowCoords
    }
    
    func drawRoom(room: MapRoom, rect: NSRect) {
        if let targetLoc = roomDrawLocation(room) {
            let path = NSBezierPath(rect: NSMakeRect(targetLoc.x - _zoom/2, targetLoc.y - _zoom/2, _zoom, _zoom))
            room.color.setFill()
            path.fill()
        }
    }
    
    func drawExit(exit: MapExit, rect: NSRect) {
        if (exit.direction < 9) {
            let dir = exit.direction
            if (dir != 1 && dir != 3 && dir != 5 && dir != 7) {
                Swift.print("Direction: \(exit.direction)")
            }
            if let fromRoom = exit.fromRoom {
                if let toRoom = exit.toRoom {
                    if (toRoom.zoneId == fromRoom.zoneId) {
                        if let fromLoc = roomDrawLocation(fromRoom) {
                            if let toLoc = roomDrawLocation(toRoom) {
                                if (NSPointInRect(fromLoc, bounds) || NSPointInRect(toLoc, bounds)) {
                                    let path = NSBezierPath()
                                    path.moveToPoint(fromLoc)
                                    path.lineToPoint(toLoc)
                                    NSColor.blackColor().setStroke()
                                    path.stroke()
                                }
                            }
                        }
                    } else {
                        // TODO: Draw exit stub for placeholder.
                    }
                }
            }
        }
    }
    
    func markCurrentRoom() {
        if let centerRoom = _currentRoom {
            if let targetLoc = roomDrawLocation(centerRoom) {
                let path = NSBezierPath(ovalInRect: NSMakeRect(targetLoc.x - _zoom/4, targetLoc.y - _zoom/4, _zoom / 2, _zoom / 2))
                NSColor.redColor().setFill()
                path.fill()
            }
        }
    }
}