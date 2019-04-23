# Path Tesselate

### Create a CGPath
### Tesselate it
### Draw it with metal

Example based on these:

http://metalbyexample.com/text-3d/
### libtess2
https://github.com/memononen/libtess2/tree/master/Source

### Tessellation
https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Tessellation/Tessellation.html


The Model I/O framework
http://metalkit.org/2016/08/30/the-model-i-o-framework.html


### Bezier curves, formulas
https://andreygordeev.com/2017/03/13/uibezierpath-closest-point/


For each path type (Line, Quad curve, Cube curve) we’ll calculate points for given t, where t is in 0.0..<1.0, with using an appropriate formula. Formulas are pretty simple:

 Calculates a point at given t value, where t in 0.0...1.0

```
private func calculateLinear(t: CGFloat, p1: CGPoint, p2: CGPoint) -> CGPoint {
    let mt = 1 - t
    let x = mt * p1.x + t * p2.x
    let y = mt * p1.y + t * p2.y
    return CGPoint(x: x, y: y)
}
```

 Calculates a point at given t value, where t in 0.0...1.0


```
private func calculateCube(t: CGFloat, p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint) -> CGPoint {
    let mt = 1 - t
    let mt2 = mt * mt
    let t2 = t * t

    let a = mt2*mt
    let b = mt2*t*3
    let c = mt*t2*3
    let d = t*t2

    let x = a*p1.x + b*p2.x + c*p3.x + d*p4.x
    let y = a*p1.y + b*p2.y + c*p3.y + d*p4.y
    return CGPoint(x: x, y: y)
}
```

 Calculates a point at given t value, where t in 0.0...1.0

```
private func calculateQuad(t: CGFloat, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
    let mt = 1 - t
    let mt2 = mt * mt
    let t2 = t * t

    let a = mt2
    let b = mt*t*2
    let c = t2

    let x = a*p1.x + b*p2.x + c*p3.x
    let y = a*p1.y + b*p2.y + c*p3.y
    return CGPoint(x: x, y: y)
}
```

### Winding Rules
![Winding Rules](./WindingRules.gif)

