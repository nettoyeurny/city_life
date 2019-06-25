library portal;

import 'package:chronosgl/chronosgl.dart';


final ShaderObject VertexShader = ShaderObject("PortalV")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddVaryingVars([vColor])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime, uPointSize])
  ..SetBody([
    """
float rand(vec2 xy){
     return fract(sin(dot(xy, vec2(12.9898, 78.233))) * 43758.5453);
}
     
vec3 noise(vec3 orig, float t) {
       return vec3(rand(vec2(t + float(gl_VertexID), orig.x)),
                   rand(vec2(t + float(gl_VertexID), orig.y)),
                   rand(vec2(t + float(gl_VertexID), orig.z)));
}

void main() {
    vec3 pos = ${aPosition} + 2.0 * noise(${aPosition}, ${uTime});

    gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(pos, 1.0);
                   
    gl_PointSize = ${uPointSize} / gl_Position.z;
    
     //${vColor} = vec3(0.5, 0.5, 0.5);
    ${vColor} = noise(${aPosition}, ${uTime} * 2.0)  * 0.3 + vec3(0.3, 0.3, 0.3); 
}
"""
  ]);

final ShaderObject FragmentShader = ShaderObject("PortalF")
  ..AddVaryingVars([vColor])
  ..SetBody([
    """
void main() {  
    ${oFragColor}.rgb = ${vColor};
}
    """
  ]);


MeshData MakePortal(RenderProgram program) {
  final detail = 4;
  final MeshData torus = ShapeTorusKnot(program,
      radius: 1.0 * 20,
      tubeRadius: 0.3 * 20,
      computeNormals: true,
      segmentsR: 256 * detail,
      segmentsT: 16 * detail);
  print("TOROS: ${torus}");
  return ExtractPointCloud(program, torus);
}
