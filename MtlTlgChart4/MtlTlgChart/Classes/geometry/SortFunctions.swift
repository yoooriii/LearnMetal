//
//  SortFunctions.swift
//  MtlTlgChart4
//
//  Updated by leonid@leeloo on 5/23/19 ©2019 Horns&Hoofs.®
//

import Foundation

struct ExtremIndex {
    let value: Int64
    let index: Int
}

class SortFunctions {
    struct ExtremItem: Hashable {
        let index: Int
        let isMax: Bool
        let plane: Int
        var hashValue: Int { get { return index } }
        public static func == (lhs:ExtremItem, rhs:ExtremItem) -> Bool {
            return lhs.index == rhs.index
        }
    }
    
    static func findExtremums(vectors:[Vector], countInSet:Int) -> Set<ExtremItem> {
        var combinedExtremums = Set<ExtremItem>()
        var plane = 0
        for vector in vectors {
            let extremums = findExtremums(vector:vector, countInSet:countInSet, plane:plane)
            combinedExtremums = combinedExtremums.union(extremums)
            plane += 1
        }
        return combinedExtremums
    }
    
    static func findExtremums(vector:Vector, countInSet:Int, plane:Int) -> [ExtremItem] {
        var indices = [ExtremItem]()

        let vSize = vector.values.count
        var stepCount = vSize / countInSet
        if stepCount < 8 {
            stepCount = vSize / 8
        }
        if stepCount * 2 >= vSize {
            stepCount = vSize
        }
        if stepCount < 1 {
            return indices
        }
        
        var i = 0
        while i < vSize {
            var min = ExtremIndex(value: vector.values[i], index: i)
            var max = min
            let endIndex = (i + 2 * stepCount) >= vSize ? vSize : (i + stepCount)
            for j in (i + 1) ..< endIndex {
                let val = vector.values[i]
                if min.value > val { min = ExtremIndex(value: val, index: j) }
                if max.value < val { max = ExtremIndex(value: val, index: j) }
            }
            
//            for j in min.index ..< vSize {
//                let val = vector.values[j]
//                if min.value > val {
//                    min = ExtremIndex(value: val, index: j)
//                    for k in 0 ..< probeCount {
//                        let val = vector.values[k]
//
//                    }
//                    break;
//                }
//            }
            
            
            
            indices.append(ExtremItem(index: max.index, isMax: true, plane:plane))
            indices.append(ExtremItem(index: min.index, isMax: false, plane:plane))
            
            i += stepCount
        }
        
        return indices
    }
    
    static func findMaximums(vector:Vector, countInSet:Int) -> [Int] {
        var foundMax = [Int]()
        var i = 0
        let vSize = vector.values.count
        let dy = Int64(0) // (vector.maxValue - vector.minValue)/Int64(vSize) * 10 // <<<
        while i < vSize {
            let iMax = vector.max(in: NSMakeRange(i, countInSet))
            var max1 = vector.values[iMax]
            var max2 = max1
            var maxIndx1 = iMax
            var maxIndx2 = maxIndx1
            if i > 0 {
                let minIndex = foundMax.last ?? 0
                for j in stride(from: iMax - 1, to: minIndex, by: -1) {
                    let val = vector.values[j]
                    if val > max1 {
                        max1 = val
                        maxIndx1 = j
                    } else {
                        break
                        if val < max1 - dy {
                            break
                        }
                    }
                }
            }
            
            for j in iMax + 1 ..< vSize {
                let val = vector.values[j]
                if val > max2 {
                    max2 = val
                    maxIndx2 = j
                } else {
                    break
                    if val < max2 - dy {
                        break
                    }
                }
            }
            
            let foundIndex = max1 > max2 ? maxIndx1 : maxIndx2
            if !foundMax.contains(foundIndex) {
                foundMax.append(foundIndex)
            }
            
            i = maxIndx2 + 1
        }
        return foundMax
    }
}

extension Int {
    static func min(_ x:Int, _ y:Int) -> Int {
        return (x > y) ? y : x;
    }

    static func max(_ x:Int, _ y:Int) -> Int {
        return (x > y) ? x : y;
    }
}

extension Vector {
    // return the index of the min value
    func min(in range: NSRange) -> Int {
        let start = Int.max(0, range.location)
        if start >= values.count {
            return -1
        }
        
        let end = Int.min(start + range.length, values.count - 1)
        var min = values[start]
        var minIndex = start
        for i in start + 1 ..< end {
            let val = values[i]
            if min > val {
                min = val
                minIndex = i
            }
        }
        
        return minIndex
    }

    // return the index of the max value
    func max(in range: NSRange) -> Int {
        let start = Int.max(0, range.location)
        if start >= values.count {
            return -1
        }
        
        let end = Int.min(start + range.length, values.count - 1)
        var max = values[start]
        var maxIndex = start
        if start + 1 < end {
            for i in start + 1 ..< end {
                let val = values[i]
                if max < val {
                    max = val
                    maxIndex = i
                }
            }
        }
        
        return maxIndex
    }
}
