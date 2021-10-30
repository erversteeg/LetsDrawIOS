//
//  InteractiveCanvas.swift
//  LiquidOceanIOS
//
//  Created by Eric Versteeg on 2/10/21.
//  Copyright © 2021 Eric Versteeg. All rights reserved.
//

import UIKit
import SocketIO

protocol InteractiveCanvasDrawCallback: AnyObject {
    func notifyCanvasRedraw()
}

protocol InteractiveCanvasScaleCallback: AnyObject {
    func notifyScaleCancelled()
}

protocol InteractiveCanvasPaintDelegate: AnyObject {
    func notifyPaintingStarted()
    func notifyPaintingEnded()
    func notifyPaintColorUpdate()
}

protocol InteractiveCanvasPixelHistoryDelegate: AnyObject {
    func notifyShowPixelHistory(data: [AnyObject], screenPoint: CGPoint)
    func notifyHidePixelHistory()
}

protocol InteractiveCanvasRecentColorsDelegate: AnyObject {
    func notifyNewRecentColors(recentColors: [Int32])
}

protocol InteractiveCanvasArtExportDelegate: AnyObject {
    func notifyArtExported(art: [InteractiveCanvas.RestorePoint])
}

protocol InteractiveCanvasSocketStatusDelegate: AnyObject {
    func notifySocketError()
}

class InteractiveCanvas: NSObject {
    var rows = 1024
    var cols = 1024
    
    var arr = [[Int32]]()
    
    var basePpu = 100
    var ppu: Int!
    
    var gridLineThreshold = 19
    
    var deviceViewport: CGRect!
    
    private var _world: Bool = false
    var world: Bool {
        set {
            _world = newValue
            initType()
        }
        get {
            return _world
        }
    }
    
    var realmId = 0
    
    weak var drawCallback: InteractiveCanvasDrawCallback?
    weak var scaleCallback: InteractiveCanvasScaleCallback?
    weak var paintDelegate: InteractiveCanvasPaintDelegate?
    weak var pixelHistoryDelegate: InteractiveCanvasPixelHistoryDelegate?
    weak var recentColorsDelegate: InteractiveCanvasRecentColorsDelegate?
    weak var artExportDelegate: InteractiveCanvasArtExportDelegate?
    
    var startScaleFactor = CGFloat(0.2)
    
    let minScaleFactor = CGFloat(0.07)
    let maxScaleFactor = CGFloat(7)
    
    var recentColors = [Int32]()
    
    let backgroundBlack = 0
    let backgroundWhite = 1
    let backgroundGrayThirds = 2
    let backgroundPhotoshop = 3
    let backgroundClassic = 4
    let backgroundChess = 5
    
    let numBackgrounds = 6
    
    var restorePoints =  [RestorePoint]()
    var pixelsOut: [RestorePoint]!
    
    var receivedPaintRecently = false
    
    class RestorePoint {
        var x: Int
        var y: Int
        var color: Int32
        var newColor: Int32
        
        init(x: Int, y: Int, color: Int32, newColor: Int32) {
            self.x = x
            self.y = y
            self.color = color
            self.newColor = newColor
        }
    }
    
    class ShortTermPixel {
        var restorePoint: RestorePoint
        var time: Double
        
        init(restorePoint: RestorePoint) {
            self.restorePoint = restorePoint
            self.time = Date().timeIntervalSince1970
        }
    }
    
    override init() {
        super.init()
        
    }
    
    func initType() {
        if world {
            // world
            if realmId == 1 {
                rows = 1024
                cols = 1024
                initChunkPixelsFromMemory()
            }
            // dev
            else {
                let dataJsonStr = SessionSettings.instance.userDefaults().object(forKey: "arr") as? String
                initPixels(arrJsonStr: dataJsonStr!)
            }
            
            registerForSocketEvents(socket: InteractiveCanvasSocket.instance.socket)
        }
        // single play
        else {
            let dataJsonStr = SessionSettings.instance.userDefaults().object(forKey: "arr_single") as? String
            
            if dataJsonStr == nil {
                loadDefault()
            }
            else {
                initPixels(arrJsonStr: dataJsonStr!)
            }
        }
        
        // short term pixels
        for shortTermPixel in SessionSettings.instance.shortTermPixels {
            let x = shortTermPixel.restorePoint.x
            let y = shortTermPixel.restorePoint.y
            
            arr[y][x] = shortTermPixel.restorePoint.color
        }
        
        // both
        ppu = basePpu
        
        let recentColorsJsonStr = SessionSettings.instance.userDefaultsString(forKey: "recent_colors", defaultVal: "")
        
        do {
            if recentColorsJsonStr != "" {
                let recentColorsArr = try JSONSerialization.jsonObject(with: recentColorsJsonStr.data(using: .utf8)!, options: []) as! [AnyObject]
                let sizeDiff = SessionSettings.instance.numRecentColors - recentColorsArr.count
                
                if sizeDiff < 0 {
                    for i in 0...SessionSettings.instance.numRecentColors - 1 {
                        self.recentColors.append(recentColorsArr[-sizeDiff + i] as! Int32)
                    }
                }
                else {
                    for i in 0...recentColorsArr.count - 1 {
                        self.recentColors.append(recentColorsArr[i] as! Int32)
                    }
                    
                    if sizeDiff > 0 {
                        let gridLineColor = self.getGridLineColor()
                        for _ in 0...sizeDiff - 1 {
                            self.recentColors.insert(gridLineColor, at: 0)
                        }
                    }
                }
            }
            else {
                let gridLineColor = self.getGridLineColor()
                for i in 0...SessionSettings.instance.numRecentColors - 1 {
                    // default to size - 1 of the grid line color
                    if i < SessionSettings.instance.numRecentColors - 1 {
                        if gridLineColor == ActionButtonView.blackColor {
                            self.recentColors.append(ActionButtonView.blackColor)
                        }
                        else {
                            self.recentColors.append(ActionButtonView.whiteColor)
                        }
                    }
                    // and 1 of the opposite color
                    else {
                        if gridLineColor == ActionButtonView.blackColor {
                            self.recentColors.append(ActionButtonView.whiteColor)
                        }
                        else {
                            self.recentColors.append(ActionButtonView.blackColor)
                        }
                    }
                }
            }
        }
        catch {
            
        }
    }
    
    func registerForSocketEvents(socket: SocketIOClient) {
        var shortTermPixels = [ShortTermPixel]()
        
        socket.on("pixels_commit") { (data, ack) in
            let pixelsJsonArr = data[0] as! [[String: Any]]
            
            for pixelObj in pixelsJsonArr {
                var sameRealm = false
                
                var unit1DIndex = (pixelObj["id"] as! Int) - 1
                
                if unit1DIndex < (512 * 512) && self.realmId == 2 {
                    sameRealm = true
                }
                else if (unit1DIndex >= (512 * 512) && self.realmId == 1) {
                    sameRealm = true
                }
                
                if self.realmId == 1 {
                    unit1DIndex -= (512 * 512)
                }
                
                if (sameRealm) {
                    let y = unit1DIndex / self.cols
                    let x = unit1DIndex % self.cols
                    
                    let color = pixelObj["color"] as! Int32
                    self.arr[y][x] = color
                    
                    shortTermPixels.append(ShortTermPixel(restorePoint: RestorePoint(x: x, y: y, color: color, newColor: color)))
                }
            }
            
            SessionSettings.instance.addShortTermPixels(pixels: shortTermPixels)
            
            self.drawCallback?.notifyCanvasRedraw()
        }
        
        socket.on("add_paint_canvas_setup") { (data, ack) in
            if !self.receivedPaintRecently {
                SessionSettings.instance.dropsAmt = Int(fmin(Double(SessionSettings.instance.dropsAmt + 50), 1000.0))
                
                self.receivedPaintRecently = true
                Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { (tmr) in
                    self.receivedPaintRecently = false
                }
            }
        }
    }
    
    func initPixels(arrJsonStr: String) {
        do {
            if let outerArray = try JSONSerialization.jsonObject(with: arrJsonStr.data(using: .utf8)!, options: []) as? [Any] {
                
                for i in 0...outerArray.count - 1 {
                    let innerArr = outerArray[i] as! [Int32]
                    var arrRow = [Int32]()
                    for j in 0...innerArr.count - 1 {
                        arrRow.append(innerArr[j])
                    }
                    arr.append(arrRow)
                }
            }
        }
        catch {
            
        }
    }
    
    func initChunkPixelsFromMemory() {
        var chunk = [[Int32]]()
        for i in 0...cols - 1 {
            var innerArr = [Int32]()
            if i < rows / 4 {
                chunk = SessionSettings.instance.chunk1
            }
            else if i < rows / 2 {
                chunk = SessionSettings.instance.chunk2
            }
            else if i < rows - (rows / 4) {
                chunk = SessionSettings.instance.chunk3
            }
            else {
                chunk = SessionSettings.instance.chunk4
            }
            
            for j in 0...rows - 1 {
                innerArr.append(chunk[i % 256][j])
            }
            
            arr.append(innerArr)
        }
    }
    
    func loadDefault() {
        for i in 0...rows - 1 {
            var innerArr = [Int32]()
            for j in 0...cols - 1 {
                if (i + j) % 2 == 0 {
                    innerArr.append(0)
                }
                else {
                    innerArr.append(0)
                }
            }
            
            arr.append(innerArr)
        }
    }
    
    func save() {
        if world {
            do {
                SessionSettings.instance.userDefaults().set(try JSONSerialization.data(withJSONObject: arr, options: .fragmentsAllowed), forKey: "arr")
            }
            catch {
                
            }
        }
        else {
            do {
                let data = try JSONSerialization.data(withJSONObject: self.arr, options: [])
                SessionSettings.instance.userDefaults().set(String(data: data, encoding: .utf8), forKey: "arr_single")
            }
            catch {
                
            }
        }
    }
    
    func isCanvas(unitPoint: CGPoint) -> Bool {
        return unitPoint.x > 0 && unitPoint.y > 0 && unitPoint.x < CGFloat(cols) && unitPoint.y < CGFloat(rows)
    }
    
    func isBackground(unitPoint: CGPoint) -> Bool {
        return unitPoint.x < 0 || unitPoint.y < 0 || unitPoint.x > CGFloat(cols - 1) || unitPoint.y > CGFloat(rows - 1) || arr[Int(unitPoint.y)][Int(unitPoint.x)] == 0
    }
    
    func paintUnitOrUndo(x: Int, y: Int, mode: Int = 0) {
        let restorePoint = unitInRestorePoints(x: x, y: y, restorePointsArr: self.restorePoints)
        
        if mode == 0 {
            if restorePoint == nil && (SessionSettings.instance.dropsAmt > 0 || !world) {
                if x > -1 && x < cols && y > -1 && y < rows {
                    let unitColor = arr[y][x]
                    
                    if SessionSettings.instance.paintColor != unitColor {
                        // paint
                        restorePoints.append(RestorePoint(x: x, y: y, color: arr[y][x], newColor: SessionSettings.instance.paintColor!))
                        
                        arr[y][x] = SessionSettings.instance.paintColor
                        
                        SessionSettings.instance.dropsAmt -= 1
                    }
                }
            }
        }
        else if mode == 1 {
            if restorePoint != nil {
                let index = restorePoints.firstIndex{$0 === restorePoint}
                
                if index != nil {
                    restorePoints.remove(at: index!)
                    arr[y][x] = restorePoint!.color
                    
                    SessionSettings.instance.dropsAmt += 1
                }
            }
        }
        
        drawCallback?.notifyCanvasRedraw()
    }
    
    func commitPixels() {
        if world {
            print(SessionSettings.instance.paintColor)
            
            var pixelInfoArr = [[String: Int32]]()
            
            for restorePoint in self.restorePoints {
                var map = [String: Int32]()
                
                if realmId == 1 {
                    map["id"] = Int32((restorePoint.y * cols + restorePoint.x) + 1 + (512 * 512))
                }
                else {
                    map["id"] = Int32((restorePoint.y * cols + restorePoint.x) + 1)
                }
                map["color"] = restorePoint.newColor
                
                pixelInfoArr.append(map)
            }
            
            var reqObj = [String: Any]()
            
            reqObj["uuid"] = SessionSettings.instance.uniqueId
            reqObj["pixels"] = pixelInfoArr
            
            print(reqObj)
            
            InteractiveCanvasSocket.instance.socket.emit("pixels_event", reqObj)
            
            StatTracker.instance.reportEvent(eventType: .pixelPaintedWorld, amt: restorePoints.count)
        }
        else {
            StatTracker.instance.reportEvent(eventType: .pixelPaintedSingle, amt: restorePoints.count)
        }
        
        updateRecentColors()
        self.recentColorsDelegate?.notifyNewRecentColors(recentColors: self.recentColors)
    }
    
    private func updateRecentColors() {
        var colorIndex = -1
        for restorePoint in self.restorePoints {
            var contains = false
            for i in 0...recentColors.count - 1 {
                if restorePoint.newColor == self.recentColors[i] {
                    contains = true
                    colorIndex = i
                }
            }
            if !contains {
                if self.recentColors.count == SessionSettings.instance.numRecentColors {
                    recentColors.remove(at: 0)
                }
                self.recentColors.append(restorePoint.newColor)
            }
            else {
                self.recentColors.remove(at: colorIndex)
                self.recentColors.append(restorePoint.newColor)
            }
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: self.recentColors, options: [])
            let str = String(data: data, encoding: .utf8)
            
            SessionSettings.instance.userDefaults().set(str, forKey: "recent_colors")
        }
        catch {
            
        }
    }
    
    func getGridLineColor() -> Int32 {
        if SessionSettings.instance.gridLineColor != 0 {
            return SessionSettings.instance.gridLineColor
        }
        else {
            let white = Utils.int32FromColorHex(hex: "0xFFFFFFFF")
            let black = Utils.int32FromColorHex(hex: "0xFF000000")
            switch SessionSettings.instance.backgroundColorIndex {
                case backgroundWhite:
                    return black
                case backgroundPhotoshop:
                    return black
                default:
                    return white
            }
        }
    }
    
    func getBackgroundColors(index: Int) -> (primary: Int32, secondary: Int32)? {
        switch index {
            case backgroundBlack:
                return (Utils.int32FromColorHex(hex: "0xFF000000"), Utils.int32FromColorHex(hex: "0xFF000000"))
            case backgroundWhite:
                return (Utils.int32FromColorHex(hex: "0xFFFFFFFF"), Utils.int32FromColorHex(hex: "0xFFFFFFFF"))
            case backgroundGrayThirds:
                return (Utils.int32FromColorHex(hex: "0xFFAAAAAA"), Utils.int32FromColorHex(hex: "0xFF555555"))
            case backgroundPhotoshop:
                return (Utils.int32FromColorHex(hex: "0xFFFFFFFF"), Utils.int32FromColorHex(hex: "0xFFCCCCCC"))
            case backgroundClassic:
                return (Utils.int32FromColorHex(hex: "0xFF666666"), Utils.int32FromColorHex(hex: "0xFF333333"))
            case backgroundChess:
                return (Utils.int32FromColorHex(hex: "0xFFB59870"), Utils.int32FromColorHex(hex: "0xFF000000"))
            default:
                return nil
        }
    }
    
    func getPixelHistoryForUnitPoint(unitPoint: CGPoint, completionHandler: @escaping (Bool, [AnyObject]) -> Void) {
        let x = Int(unitPoint.x)
        let y = Int(unitPoint.y)
        
        var pixelId = y * cols + x + 1
        if realmId == 1 {
            pixelId += (512 * 512)
        }
        
        URLSessionHandler.instance.downloadPixelHistory(pixelId: pixelId, completionHandler: completionHandler)
    }
    
    // restore points
    
    func undoPendingPaint() {
        for restorePoint: RestorePoint in restorePoints {
            arr[restorePoint.y][restorePoint.x] = restorePoint.color
        }
    }
    
    func clearRestorePoints() {
        self.restorePoints = [RestorePoint]()
    }
    
    func unitInRestorePoints(x: Int, y: Int, restorePointsArr: [RestorePoint]) -> RestorePoint? {
        for restorePoint in restorePointsArr {
            if restorePoint.x == x && restorePoint.y == y {
                return restorePoint
            }
        }
        
        return nil
    }
    
    func exportSelection(startUnit: CGPoint, endUnit: CGPoint) {
        var pixelsOut = [RestorePoint]()
        
        var numLeadingCols = 0
        var numTrailingCols = 0
        
        var numLeadingRows = 0
        var numTrailingRows = 0
        
        let startX = Int(startUnit.x)
        let startY = Int(startUnit.y)
        
        let endX  = Int(endUnit.x)
        let endY = Int(endUnit.y)
        
        var before = true
        for x in startX...endX {
            var clear = true
            for y in startY...endY {
                if arr[y][x] != 0 {
                    clear = false
                    before = false
                }
            }
            
            if clear && before {
                numLeadingCols += 1
            }
        }
        
        before = true
        for xi in startX...endX {
            let x = (endX - xi) + startX
            var clear = true
            for y in startY...endY {
                if arr[y][x] != 0 {
                    clear = false
                    before = false
                }
            }
            
            if clear && before {
                numTrailingCols += 1
            }
        }
        
        before = true
        for y in startY...endY {
            var clear = true
            for x in startX...endX {
                if arr[y][x] != 0 {
                    clear = false
                    before = false
                }
            }
            
            if clear && before {
                numLeadingRows += 1
            }
        }
        
        before = true
        for yi in startY...endY {
            let y = (endY - yi) + startY
            var clear = true
            for x in startX...endX {
                if arr[y][x] != 0 {
                    clear = false
                    before = false
                }
            }
            
            if clear && before {
                numTrailingRows += 1
            }
        }
        
        if (startX + numLeadingCols) < (endX - numTrailingCols) &&
            (startY + numLeadingRows) < (endY - numTrailingRows) {
            for x in (startX + numLeadingCols)...(endX - numTrailingCols) {
                for y in (startY + numLeadingRows)...(endY - numTrailingRows) {
                    pixelsOut.append(RestorePoint(x: x, y: y, color: arr[y][x], newColor: arr[y][x]))
                }
            }
        }
        
        artExportDelegate?.notifyArtExported(art: pixelsOut)
    }
    
    func exportSelection(unitPoint: CGPoint) {
        self.artExportDelegate?.notifyArtExported(art: getPixelsInForm(unitPoint: unitPoint))
    }
    
    private func getPixelsInForm(unitPoint: CGPoint) -> [RestorePoint] {
        pixelsOut = [RestorePoint]()
        stepPixelsInForm(x: Int(unitPoint.x), y: Int(unitPoint.y), depth: 0)
        
        return pixelsOut
    }
    
    private func stepPixelsInForm(x: Int, y: Int, depth: Int) {
        // a background color
        // or already in list
        // or out of bounds
        if x < 0 || x > cols - 1 || y < 0 || y > rows - 1 || arr[y][x] == 0 || unitInRestorePoints(x: x, y: y, restorePointsArr: pixelsOut) != nil || depth > 10000 {
            return
        }
        else {
            pixelsOut.append(RestorePoint(x: x, y: y, color: arr[y][x], newColor: arr[y][x]))
        }
        
        // left
        stepPixelsInForm(x: x - 1, y: y, depth: depth + 1)
        // top
        stepPixelsInForm(x: x, y: y - 1, depth: depth + 1)
        // right
        stepPixelsInForm(x: x + 1, y: y, depth: depth + 1)
        // bottom
        stepPixelsInForm(x: x, y: y + 1, depth: depth + 1)
        // top-left
        stepPixelsInForm(x: x - 1, y: y - 1, depth: depth + 1)
        // top-right
        stepPixelsInForm(x: x + 1, y: y - 1, depth: depth + 1)
        // bottom-left
        stepPixelsInForm(x: x - 1, y: y + 1, depth: depth + 1)
        // bottom-right
        stepPixelsInForm(x: x + 1, y: y + 1, depth: depth + 1)
        
    }
    
    func updateDeviceViewport(screenSize: CGSize, fromScale: Bool = false) {
        updateDeviceViewport(screenSize: screenSize, canvasCenterX: deviceViewport.origin.x + deviceViewport.size.width / 2, canvasCenterY: deviceViewport.origin.y + deviceViewport.size.height / 2, fromScale: fromScale)
    }
    
    func updateDeviceViewport(screenSize: CGSize, canvasCenterX: CGFloat, canvasCenterY: CGFloat, fromScale: Bool = false) {
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        let canvasCenterXPx = Int((canvasCenterX * CGFloat(ppu)))
        let canvasCenterYPx = Int((canvasCenterY * CGFloat(ppu)))
        
        let canvasTop = canvasCenterYPx - Int(screenHeight) / 2
        let canvasBottom = canvasCenterYPx + Int(screenHeight) / 2
        let canvasLeft = canvasCenterXPx - Int(screenWidth) / 2
        let canvasRight = canvasCenterXPx + Int(screenWidth) / 2
        
        let top = CGFloat(canvasTop) / CGFloat(ppu)
        let bottom = CGFloat(canvasBottom) / CGFloat(ppu)
        let left = CGFloat(canvasLeft) / CGFloat(ppu)
        let right = CGFloat(canvasRight) / CGFloat(ppu)
        
        if (top < 0.0 || bottom > CGFloat(rows) || CGFloat(left) < 0.0 || right > CGFloat(cols)) {
            if (fromScale) {
                self.scaleCallback?.notifyScaleCancelled()
                return
            }
        }
        
        deviceViewport = CGRect(x: left, y: top, width: (right - left), height: (bottom - top))
    }
    
    func getScreenSpaceForUnit(x: Int, y: Int) -> CGRect {
        let offsetX = (CGFloat(x) - deviceViewport.origin.x) * CGFloat(ppu)
        let offsetY = (CGFloat(y) - deviceViewport.origin.y) * CGFloat(ppu)
        
        return CGRect(x: round(max(offsetX, 0.0)), y: round(max(offsetY, 0.0)), width: round(offsetX + CGFloat(ppu)), height: round(offsetY + CGFloat(ppu)))
    }
    
    func unitForScreenPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        let topViewportPx = deviceViewport.origin.y * CGFloat(ppu)
        let leftViewportPx = deviceViewport.origin.x * CGFloat(ppu)
        
        let absXPx = leftViewportPx + x
        let absYPx = topViewportPx + y
        
        let absX = absXPx / CGFloat(ppu)
        let absY = absYPx / CGFloat(ppu)
        
        return CGPoint(x: floor(absX), y: floor(absY))
    }
    
    func translateBy(x: CGFloat, y: CGFloat) {
        let margin = CGFloat(200) / CGFloat(ppu)
        
        var dX = x / CGFloat(ppu)
        var dY = y / CGFloat(ppu)
        
        var left = deviceViewport.origin.x
        var top = deviceViewport.origin.y
        var right = left + deviceViewport.size.width
        var bottom = top + deviceViewport.size.height
        
        let leftBound = -margin
        if left + dX < leftBound {
            let diff = left - leftBound
            dX = diff
        }
        
        let rightBound = CGFloat(self.cols) + margin
        if right + dX > rightBound {
            let diff = rightBound - right
            dX = diff
        }
        
        let topBound = -margin
        if top + dY < topBound {
            let diff = top - topBound
            dY = diff
        }
        
        let bottomBound = CGFloat(self.rows) + margin
        if bottom + dY > CGFloat(rows) {
            let diff = bottomBound - bottom
            dY = diff
        }
        
        left += dX
        right += dX
        top += dY
        bottom += dY
        
        deviceViewport = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        
        drawCallback?.notifyCanvasRedraw()
    }
}
