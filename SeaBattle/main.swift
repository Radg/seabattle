//
//  main.swift
//  SeaBattle
//
//  Created by Radic on 09/01/2019.
//  Copyright © 2019 Radic. All rights reserved.
//

import Cocoa

struct Point2D: Hashable {
    var col : Int = 0
    var row : Int = 0
    
    var hashValue: Int {
        return "(\(col),\(row))".hashValue
    }
    
    static func == (lhs: Point2D, rhs: Point2D) -> Bool {
        return lhs.col == rhs.col && lhs.row == rhs.row
    }
}

class GameBoard {
    
    var boardSize: Int = 10
    let columnNames = "АБВГДЕЖЗИК"
    let columns: [Character:Int] = ["А": 1, "Б": 2, "В": 3, "Г": 4, "Д": 5, "Е": 6, "Ж": 7, "З": 8, "И": 9, "К": 10]
    let maxShipSize = 4
    
    enum HitResult {
        case Miss
        case Wound
        case Dead
        case AlreadyShooted
        case Unknown
    }
    
    // Игровое поле - матрица Int 12х12. Периметр - нулевые клетки.
    // 0 - клетка не занята
    // -64 - сюда стрелял враг                                       // 128 - гало
    // 11 или -11 - 1я палуба 1-палубного корабля
    // 22 - 2я палуба 2-палубного горизонтального корабля           // 122 - 2я палуба 2-палубного вертикального корабля
    // 32 - 2я палуба 3-палубного горизонтального корабля           // 132 - 3я палуба 3-палубного вертикального корабля
    // 44 - 4я палуба 4-палубного горизонтального корабля           // 141 - 1я палуба 4-палубного вертикального корабля
    // Если значение палубы отрицательное - значит данная палуба повреждена
    // -255 - палуба подбитого корабля
    
    var board = Array(repeating: Array(repeating: 0, count: 12), count: 12) // Игровая доска 12х12, эффективный размер 10х10 в центре
    
    init() {
    }
    
    func getAsString() -> String {
        // Вернуть игровое поле в виде строки
        var line: String = "   " + columnNames + "\n" + "   ----------" + "\n"
        var counter = 1
        for row in 1...boardSize {
            if counter == boardSize {
                line += String(counter) + "|"
            } else {
                line += " " + String(counter) + "|"
            }
            counter += 1
            for column in 1...boardSize {
                switch board[column][row] {
                case 0, 128:
                    line += " "
                case 11, 21 ... 22, 31 ... 33, 41 ... 44, 111, 121 ... 122, 131 ... 133, 141 ... 144:
                    line += "Q"
                case -44 ... -41, -33 ... -31, -22 ... -21, -11, -111, -122 ... -121, -133 ... -131, -144 ... -141:
                    line += "X"
                case -64:
                    line += "."
                case -255:
                    line += "+"
                default:
                    line += "?"
                }
            }
            line += "\n"
        }
        
        return line
    }
    
    subscript(column: Character, row: Int) -> Int? {
        get {
            if let col = columns[column] {
                return board[col][row]
            } else {
                return nil
            }
        }
        set {
            if columnNames.contains(column) {
                if let col = columns[column] {
                    board[col][row] = newValue!
                }
            }
        }
    }
}

class OwnBoard: GameBoard {

    var aliveDecks = [Point2D : Int]() // Сюда будут складываться координаты сгенерированных палуб
    
    func isFit(col: Int, row: Int, size: Int, isHorisontal: Bool) -> Bool { // Влезет ли корабль в заданную координату
        
        if row > boardSize || row < 1 || col > boardSize || col < 1 || isHorisontal && (col + size - 1 > boardSize) || !isHorisontal && (row + size - 1 > boardSize) {
            return false
        }
        
        let (startX, startY) = (col, row)
        let (endX, endY) = isHorisontal ? (startX + size - 1, startY) : (startX, startY + size - 1)
        
        for x in startX ... endX { // Палубы корабля должны попадать на пустые клетки (на 0)
            for y in startY ... endY {
                if board[x][y] != 0 { return false }
            }
        }
        
        for x in startX - 1 ... endX + 1 { // А гало нового корабля может попадать ещё и на гало уже существующего
            for y in startY - 1 ... endY + 1 {
                if (board[x][y] != 0) && (board[x][y] != 128) { return false }
            }
        }
        
        return true
    }
    
    func imprintShip(col: Int, row: Int, size: Int, isHorisontal: Bool) -> Bool {
        // Разместить корабль в заданной координате
        if isFit(col: col, row: row, size: size, isHorisontal: isHorisontal) {
            let (startX, startY, isHorisontalDigit) = (col, row, isHorisontal ? 0 : 100)
            let (endX, endY) = isHorisontal ? (startX + size - 1, startY) : (startX, startY + size - 1)
            
            for x in startX - 1 ... endX + 1 { // Рисуем сначала гало
                for y in startY - 1 ... endY + 1 { board[x][y] = 128 }
            }
            
            var deckNumber = 1
            for x in startX ... endX { // А потом и сами палубы
                for y in startY ... endY {
                    board[x][y] = isHorisontalDigit + size * 10 + deckNumber
                    aliveDecks[Point2D(col: x, row: y)] = board[x][y]
                    deckNumber += 1
                }
            }
        } else { return false }
        
        return true
    }
    
    func getRandomAliveDeck() -> Point2D {
        var randomPoint = Point2D()
        (randomPoint, _) = aliveDecks.randomElement()!
        return randomPoint
    }
    
    func generateShips() {
        
        for shipSize in 1...maxShipSize {
            var counter = 0
            while counter < shipSize {
                if imprintShip(col: Int.random(in: 1...boardSize), row: Int.random(in: 1...boardSize), size: maxShipSize - shipSize + 1, isHorisontal: Bool.random()) {
                    counter += 1
                }
            }
        }
    }
    
    func hit(point: Point2D, playerEnemy: Player) -> HitResult {
        let (col, row) = (point.col, point.row)
        switch board[col][row] {
        case 0, 128: // Мазила!
            board[col][row] = -64
            playerEnemy.gameBoardForeign.board[col][row] = -64
            playerEnemy.gameBoardForeign.unknownCells.removeValue(forKey: point)
            return .Miss
        case -64, 256, -44 ... -11 :
            return .AlreadyShooted
        case 11, 21 ... 22, 31 ... 33, 41 ... 44, 111, 121 ... 122, 131 ... 133, 141 ... 144:
            let deckIndex = board[col][row] % 10
            let shipSize = board[col][row] < 100 ? (board[col][row] - deckIndex) / 10 : ((board[col][row] - (board[col][row] - (board[col][row] % 100))) - (board[col][row] - (board[col][row] - (board[col][row] % 100))) % 10) / 10 // Math, bitches!
            let (shipStartX, shipStartY) = board[col][row] < 100 ? ((col - deckIndex + 1), row) : (col, (row - deckIndex + 1))
            let (endX, endY) = board[col][row] < 100 ? (shipStartX + shipSize - 1, shipStartY) : (shipStartX, shipStartY + shipSize - 1)
            
            board[col][row] = -board[col][row] // Пробой палубы!
            aliveDecks.removeValue(forKey: Point2D(col: col, row: row)) // Убираем эту палубу из словаря живых
            
            playerEnemy.gameBoardForeign.board[col][row] = -playerEnemy.gameBoardForeign.board[col][row] // Зеркалируем пробой на чужой карте противоположного игрока
            playerEnemy.gameBoardForeign.unknownCells.removeValue(forKey: point) // И убираем эту клетку из словаря свободных клеток чужой карты противоположного игрока
            
            for x in shipStartX ... endX { // Ищем живые палубы
                for y in shipStartY ... endY {
                    if board[x][y] > 0 { return .Wound }
                }
            }
            
            // Если мы тут - кораблю пиздарики
            for x in shipStartX - 1 ... endX + 1 { // Рисуем печальное гало
                for y in shipStartY - 1 ... endY + 1 {
                    board[x][y] = -64
                    playerEnemy.gameBoardForeign.board[x][y] = -64 // Зеркалируем пробой на чужой карте противоположного игрока
                    playerEnemy.gameBoardForeign.unknownCells.removeValue(forKey: Point2D(col: x, row: y)) // И убираем эту клетку из словаря неизвестных клеток чужой карты противоположного игрока
                }
            }
            
            for x in shipStartX ... endX { // R.I.P. Titanic
                for y in shipStartY ... endY {
                    board[x][y] = -255
                    playerEnemy.gameBoardForeign.board[x][y] = -255
                }
            }
            return .Dead
        default:
            return .Unknown
        }
    }

}

class ForeignBoard: GameBoard {
    
    var unknownCells = [Point2D : Int]() // Сюда будут складываться координаты клеток с неизвестным статусом (потенциальные цели для стрельбы)
    
    override init() {
        super.init()
        
        for x in 1 ... boardSize { // Заполнение словаря с неизвестными клетками
            for y in 1 ... boardSize {
                unknownCells[Point2D(col: x, row: y)] = 0
            }
        }
    }
    
    func getRandomUnknownCell() -> Point2D {
        var randomPoint = Point2D()
        (randomPoint, _) = unknownCells.randomElement()!
        return randomPoint
    }
    
}

enum CycleStatus {                  // Тип итерации:
    case NewShot                    // Совершаем новый выстрел
    case FinishNoOrientation        // Добиваем, но не знаем ориентации корабля
    case Finish                     // Добиваем, зная ориентацию корабля
}

class Player {
    var name: String                            // Имя игрока
    var gameBoardOwn: OwnBoard                  // Собственноая доска игрока
    var gameBoardForeign: ForeignBoard          // Доска противника
    var cycleStatus = CycleStatus.NewShot       // Перед началом игры статус хода игры - "Новый выстрел"
    var targetPoints = [Point2D]()              // Массив прилежащих (к раненой) клеток куда мы планируем далее стрелять, не более 4х элементов
    var woundBoards = [Point2D]()               // Массив стреляных точек

    init(name: String) {
        self.name = name
        self.gameBoardOwn = OwnBoard()
        self.gameBoardOwn.generateShips()
        self.gameBoardForeign = ForeignBoard()
    }
    
    func formTargetPoints(hitPoint: Point2D) {
        switch cycleStatus {
        case .NewShot:
            if hitPoint.col - 1 > 0  && (self.gameBoardForeign.board[hitPoint.col - 1][hitPoint.row] == 0) { self.targetPoints.append(Point2D(col: hitPoint.col - 1, row: hitPoint.row)) } // Добавляем левую точку
            if hitPoint.col + 1 < 11 && (self.gameBoardForeign.board[hitPoint.col + 1][hitPoint.row] == 0) { self.targetPoints.append(Point2D(col: hitPoint.col + 1, row: hitPoint.row)) } // Добавляем правую точку
            if hitPoint.row - 1 > 0  && (self.gameBoardForeign.board[hitPoint.col][hitPoint.row - 1] == 0) { self.targetPoints.append(Point2D(col: hitPoint.col, row: hitPoint.row - 1)) } // Добавляем верхнюю точку
            if hitPoint.row + 1 > 0  && (self.gameBoardForeign.board[hitPoint.col][hitPoint.row + 1] == 0) { self.targetPoints.append(Point2D(col: hitPoint.col, row: hitPoint.row + 1)) } // Добавляем нижнюю точку
        case .FinishNoOrientation:
            targetPoints.removeAll()
            let (minRow, maxRow) = (woundBoards.sorted(by: {$0.row < $1.row})[0].row, woundBoards.sorted(by: {$0.row > $1.row})[0].row)
            let (minCol, maxCol) = (woundBoards.sorted(by: {$0.col < $1.col})[0].col, woundBoards.sorted(by: {$0.col > $1.col})[0].col)
            if minCol == maxCol {                               // Корабль вертикальный
                // Нужно взять минимальный по row и от него -1
                if gameBoardForeign.board[woundBoards.first!.col][minRow - 1] == 0 { targetPoints.append(Point2D(col: woundBoards.first!.col, row: minRow - 1)) }
                // Нужно взять максимальный по row и от него +1
                if gameBoardForeign.board[woundBoards.first!.col][maxRow + 1] == 0 { targetPoints.append(Point2D(col: woundBoards.first!.col, row: maxRow + 1)) }
            } else {                                            // Корабль горизонтальный
                // Нужно взять минимальный по col и от него -1
                if gameBoardForeign.board[minCol - 1][woundBoards.first!.row] == 0 { targetPoints.append(Point2D(col: minCol - 1, row: woundBoards.first!.row)) }
                // Нужно взять максимальный по col и от него +1
                if gameBoardForeign.board[maxCol + 1][woundBoards.first!.row] == 0 { targetPoints.append(Point2D(col: maxCol + 1, row: woundBoards.first!.row)) }
            }
        case .Finish:
            if woundBoards.first?.col == hitPoint.col {          // Корабль вертикально
                let (minRow, maxRow) = (woundBoards.sorted(by: {$0.row < $1.row})[0].row, woundBoards.sorted(by: {$0.row > $1.row})[0].row)
                if minRow - 1 >  0 && gameBoardForeign.board[hitPoint.col][minRow - 1] == 0 { targetPoints.append(Point2D(col: hitPoint.col, row: minRow - 1)) }
                if maxRow + 1 < 11 && gameBoardForeign.board[hitPoint.col][maxRow + 1] == 0 { targetPoints.append(Point2D(col: hitPoint.col, row: maxRow + 1)) }
            } else {                                                    // Корабль горизонтально
                let (minCol, maxCol) = (woundBoards.sorted(by: {$0.col < $1.col})[0].col, woundBoards.sorted(by: {$0.col > $1.col})[0].col)
                if minCol - 1 >  0 && gameBoardForeign.board[minCol - 1][hitPoint.row] == 0 { targetPoints.append(Point2D(col: minCol - 1, row: hitPoint.row)) }
                if maxCol + 1 < 11 && gameBoardForeign.board[maxCol + 1][hitPoint.row] == 0 { targetPoints.append(Point2D(col: maxCol + 1, row: hitPoint.row)) }
            }
            if let index = targetPoints.index(of: hitPoint) { targetPoints.remove(at: index) } else { print("Ошибка удаления точки из массива прилежащих") }
        }
    }
    
}

// Тело программы

let (player1, player2) = (Player(name: "Player1"), Player(name: "Player2"))

var (playerActive, playerPassive) = (player1, player2)

print("\(player1.name) initial board is:\n", player1.gameBoardOwn.getAsString())
print("\(player2.name) initial board is:\n", player2.gameBoardOwn.getAsString())

while playerActive.gameBoardOwn.aliveDecks.count > 0 && playerPassive.gameBoardOwn.aliveDecks.count > 0 {       // Игровой цикл заканчивается как только у одного из игроков закончатся "живые" палубы
    
    var hitPoint = Point2D()
    
    switch playerActive.targetPoints.count {                                                                    // Устанавливаем cycleStatus в зависимости от кол-ва элементов массива targetPoints
    case 0:
        playerActive.cycleStatus = .NewShot
        hitPoint = playerActive.gameBoardForeign.getRandomUnknownCell()
    case 1:
        playerActive.cycleStatus = .Finish
        hitPoint = playerActive.targetPoints[0]
    default:
        playerActive.cycleStatus = .FinishNoOrientation
        hitPoint = playerActive.targetPoints.randomElement()!
    }
    
    let hitResult = playerPassive.gameBoardOwn.hit(point: hitPoint, playerEnemy: playerActive)
    switch hitResult {                                                                                          // Стреляем и анализируем результат
    case .Miss where playerActive.cycleStatus == .FinishNoOrientation || playerActive.cycleStatus == .Finish:   // На предыдущем цикле попали, в этом - промахнулись. Нужно убрать стреляную точку из массива прилежащих:
        if let index = playerActive.targetPoints.index(of: hitPoint) { playerActive.targetPoints.remove(at: index) } else { print("Ошибка удаления точки из массива прилежащих") }
        swap(&playerActive, &playerPassive)
    case .Miss:
        swap(&playerActive, &playerPassive)
    case .Wound:                                                                                                // Ранили палубу противника, нужно:
        playerActive.woundBoards.append(hitPoint)                                                                   // Добавить палубу в массив раненых
        playerActive.formTargetPoints(hitPoint: hitPoint)                                                           // Сформировать массив точек, по которым стрелять далее
    case .Dead:                                                                                                 // Убили корабль противника, нужно:
        playerActive.targetPoints.removeAll()                                                                       // Очистить массив точек, по которым стрелять далее
        playerActive.woundBoards.removeAll()                                                                        // Очистить массив раненых палуб
    case .AlreadyShooted, .Unknown:
        break
    }
}

if player1.gameBoardOwn.aliveDecks.count > 0 {
    print("\(player1.name) won!")
} else {
    print("\(player2.name) won!")
}
print("\(player1.name) result board is:\n", player1.gameBoardOwn.getAsString())
print("\(player2.name) result board is:\n", player2.gameBoardOwn.getAsString())

