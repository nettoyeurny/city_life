/// This files contains all the shading code - not all is used.
library pc_shaders;

import 'package:chronosgl/chronosgl.dart';

const String iaRotatationY = "iaRotatationY";
const String uFogColor = "uFogColor";
const String uFogEnd = "uFogEnd";
const String uFogScale = "uFogScale";
const String uWindowDim = "uWindowDim";
const String uAverageFurnitureW = "uAverageFurnitureW";
const String uMaxFurnitureH = "uMaxFurnitureH";
const String uFeatures = "uFeatures";
const String uWindowFrame = "uWindowFrame";
const String uRandSeed = "uRandSeed";
const String uWidth = "uWidth";

void IntroduceShaderVars() {
  IntroduceNewShaderVar(iaRotatationY,
      ShaderVarDesc("float", "for cars: rotation around y axis"));
  IntroduceNewShaderVar(uFogColor, ShaderVarDesc("vec3", ""));
  IntroduceNewShaderVar(uFogScale, ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uFogEnd, ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uRandSeed, ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uWindowDim, ShaderVarDesc("vec2", ""));
  IntroduceNewShaderVar(uWindowFrame, ShaderVarDesc("vec3", ""));
  IntroduceNewShaderVar(uAverageFurnitureW, ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uMaxFurnitureH, ShaderVarDesc("float", ""));
  IntroduceNewShaderVar(uFeatures, ShaderVarDesc("int", ""));
  IntroduceNewShaderVar(uWidth, ShaderVarDesc("float", ""));
}


final ShaderObject pcPointSpritesVertexShader = ShaderObject("PointSprites")
  ..AddAttributeVars([aPosition, aPointSize, aColor])
  ..AddVaryingVars([vColor])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vColor} = ${aColor};",
    "gl_PointSize = ${aPointSize}/gl_Position.z;"
  ]);

final ShaderObject pcPointSpritesFragmentShader = ShaderObject("PointSpritesF")
  ..AddVaryingVars([vColor])
  ..AddUniformVars([uTexture])
  ..SetBodyWithMain([
    """
        vec4 c = texture( ${uTexture},  gl_PointCoord);
        ${oFragColor} = c * vec4(${vColor}, 1.0 );
        """
  ]);

final ShaderObject pcPointSpritesFlashingVertexShader =
    ShaderObject("PointSpritesFlashing")
      ..AddAttributeVars([aPosition, aPointSize, aColor])
      ..AddVaryingVars([vColor, vPosition])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBodyWithMain([
        StdVertexBody,
        "${vColor} = ${aColor};",
        "gl_PointSize = ${aPointSize}/gl_Position.z;",
        "${vPosition} = ${aPosition};"
      ]);

final ShaderObject pcPointSpritesFlashingFragmentShader =
    ShaderObject("PointSpritesF")
      ..AddVaryingVars([vColor, vPosition])
      ..AddUniformVars([uTexture, uTime])
      ..SetBodyWithMain([
        """
vec4 color = texture( ${uTexture},  gl_PointCoord);
float noise1 = 10.0 * sin(${vPosition}.x + ${vPosition}.z);
float noise2 = 1.0 + 0.2 *  sin(${vPosition}.x + ${vPosition}.z);
float intensity = 0.5 + 0.5 * sin(noise1 + ${uTime} * noise2);
${oFragColor} = color * intensity * vec4(${vColor}, 1.0 );
        """
      ]);

final ShaderObject pcTexturedVertexShaderWithFog = ShaderObject("Textured")
  ..AddAttributeVars([aPosition, aTexUV, aColor])
  ..AddVaryingVars([vColor, vPosition, vTexUV])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vTexUV} = ${aTexUV};",
    "${vColor} = ${aColor};",
    "${vPosition} = (${uModelMatrix} * vec4(${aPosition}, 1.0)).xyz;"
  ]);

final ShaderObject pcTexturedFragmentShaderWithFog = ShaderObject("TexturedF")
  ..AddVaryingVars([vPosition, vColor, vTexUV])
  ..AddUniformVars([uTexture])
  ..AddUniformVars([uFogColor, uFogEnd, uFogScale])
  ..SetBodyWithMain([
    """
        vec4 c = texture(${uTexture}, ${vTexUV});
        c = c * vec4(${vColor}, 1.0 );
        float f =  clamp((uFogEnd - length(${vPosition})) * uFogScale, 0.0, 1.0);
        c = mix(vec4(uFogColor, 1.0), c, f);
        ${oFragColor} = c;
        """
  ]);

final ShaderObject pcTexturedVertexShader = ShaderObject("Textured")
  ..AddAttributeVars([aPosition, aTexUV, aColor])
  ..AddVaryingVars([vColor, vPosition, vTexUV])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vTexUV} = ${aTexUV};",
    "${vColor} = ${aColor};",
    "${vPosition} = (${uModelMatrix} * vec4(${aPosition}, 1.0)).xyz;"
  ]);

final ShaderObject pcTexturedFragmentShader = ShaderObject("TexturedF")
  ..AddVaryingVars([vPosition, vColor, vTexUV])
  ..AddUniformVars([uTexture])
  ..SetBodyWithMain([
    """
        vec4 c = texture(${uTexture}, ${vTexUV});
        c = c * vec4(${vColor}, 1.0 );
        ${oFragColor} = c;
        """
  ]);

final ShaderObject pcTexturedVertexShaderWithInstancer =
    ShaderObject("InstancedV")
      ..AddAttributeVars([aPosition, aTexUV, aColor])
      ..AddVaryingVars([vColor, vTexUV])
      ..AddAttributeVars([iaRotatationY, iaTranslation])
      ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..SetBody([
        """
vec3 rotate_position(vec3 pos, vec4 rot) {
  return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

mat4 rotationMatrix(vec3 axis, float angle) {
    vec3 a = normalize(axis);
    float x = a.x;
    float y = a.y;
    float z = a.z;
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * x * x + c,      oc * x * y - z * s,  oc * z * x + y * s,  0.0,
                oc * x * y + z * s,  oc * y * y + c,      oc * y * z - x * s,  0.0,
                oc * z * x - y * s,  oc * y * z + x * s,  oc * z * z + c,      0.0,
                0.0,                 0.0,                 0.0,                 1.0);
}


void main(void) {
  mat4 roty = rotationMatrix(vec3(0, 1, 0),  ${iaRotatationY});
  vec4 P = roty * vec4(${aPosition}, 1) + vec4(${iaTranslation}, 0);
  gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * P;
  ${vColor} = ${aColor};
  ${vTexUV} = ${aTexUV};
}
"""
      ]);

final ShaderObject pcTexturedFragmentShaderWithInstancer =
    ShaderObject("TexturedF")
      ..AddVaryingVars([vColor, vTexUV])
      ..AddUniformVars([uTexture])
      ..SetBodyWithMain([
        "${oFragColor} = texture(${uTexture}, ${vTexUV}) * vec4( ${vColor}, 1.0 );"
      ]);

final ShaderObject pcTexturedVertexShaderWithShadow = ShaderObject("Textured")
  ..AddAttributeVars([aPosition, aTexUV, aColor])
  ..AddVaryingVars([vColor, vTexUV, vPositionFromLight])
  ..AddUniformVars(
      [uPerspectiveViewMatrix, uModelMatrix, uLightPerspectiveViewMatrix])
  ..SetBodyWithMain([
    """
        vec4 pos = ${uModelMatrix} * vec4(${aPosition}, 1.0);
        gl_Position = ${uPerspectiveViewMatrix} * pos;
        ${vPositionFromLight} = ${uLightPerspectiveViewMatrix} * pos;
        ${vTexUV} = ${aTexUV};
        ${vColor} = ${aColor};
      """
  ]);

final ShaderObject pcTexturedFragmentShaderWithShadow =
    ShaderObject("TexturedF")
      ..AddVaryingVars([vColor, vTexUV, vPositionFromLight])
      ..AddUniformVars([uTexture, uShadowMap, uCanvasSize])
      ..SetBody([
        ShadowMapShaderLib,
        """
        /*
float XGetShadowPCF16(
    vec3 depth, sampler2DShadow shadowMap, float bias) {
    vec2 uv = depth.xy;
    float d = 0.0;
    for(float dx = -1.5; dx <= 1.5; dx += 1.0) {
        for(float dy =-1.5; dy <= 1.5; dy += 1.0) {
             if (depth.z - GetShadowMapValue(shadowMap, uv + vec2(dx, dy)) > bias) {
               d += 1.0 / 16.0;
             }
        }
    }
    return 1.0 - d;
}
*/

float bias1 = 0.001;
float bias2 = 0.001;

void main() {
    vec3 depth = ${vPositionFromLight}.xyz / ${vPositionFromLight}.w;
                 // depth is in [-1, 1] but we want [0, 1] for the texture lookup
    depth = 0.5 * depth + vec3(0.5);

    //float shadow = XGetShadowPCF16(depth, ${uShadowMap}, bias1);
    //float shadow = GetShadowPCF16(depth, ${uShadowMap}, bias1, bias2);
    float shadow = GetShadow(depth, ${uShadowMap}, bias1, bias2);

    shadow = shadow * 0.7 + 0.3;
    vec4 c = texture(${uTexture}, ${vTexUV});
    ${oFragColor} = c * shadow * vec4(${vColor}, 1.0 );
}
"""
      ]);

final ShaderObject facadeVertexShader = ShaderObject("facadeV")
  ..AddAttributeVars([aPosition])
  ..SetBody([NullVertexShaderString]);

// https://www.khronos.org/opengl/wiki/Built-in_Variable_(GLSL)#Fragment_shader_inputs
final ShaderObject facadeFragmentShader = ShaderObject("facadeF")
  ..AddUniformVars([
    uWindowDim,
    uAverageFurnitureW,
    uMaxFurnitureH,
    uFeatures,
    uColor,
    uWindowFrame,
    uRandSeed,
  ])
  ..SetBody([
    """
    
const float spice1 = 1.0;
const float spice2 = 2.0;
const float spice3 = 4.0;
const float spice4 = 4.0;
const float spice5 = 5.0;
const float spice6 = 6.0;

float rand(vec2 co){
     return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * (${uRandSeed} + 43758.5453));
}

float featureStart(float offset, vec2 salt) {
  float newFeatureProb = 2.0 / ${uAverageFurnitureW};
  float minFeatureWidth = floor(${uAverageFurnitureW} / 3.0);
  float start = 0.0;
  for (float i = 0.0; i < offset; i += 1.0) {
       if (rand(i * salt) < newFeatureProb) {
           start = i;
           i += minFeatureWidth;
       } 
  }
  return start;
}

float furnitureAlpha(vec2 offset, vec2 salt) {
    float h = ${uMaxFurnitureH} * rand(salt * spice1);
    if (offset.y >= h) return 1.0;
     
    float alpha1 = 0.5;
    float alpha2 =  0.25 + 0.25 * rand(salt * spice2);
    return 1.0 - mix(alpha1, alpha2, offset.y / h);
}


const float frame = 0.5;

bool isWindow(vec2 offset, float left, float bottom, float top) {
  return 
        offset.x >= left &&
        offset.y >= bottom &&
        offset.x <= ${uWindowDim}.x - left && 
        offset.y <= ${uWindowDim}.y - top;
}

bool isVerticalSplit(vec2 offset, float left) {
    float middle = ${uWindowDim}.x / 2.0;
    return offset.x >= middle - left && offset.x < middle + left; 
}

bool isHorizontalSplit(vec2 offset, float bottom, float top) {
    float middle = (${uWindowDim}.y + bottom - top) / 2.0;
    return offset.y >= middle - frame && offset.y < middle + frame; 
}


// TODO:  
// DrawFacadeWindowBlinds
// DrawFacadeWindowVerticalStripes

bool isLit(vec2 colRow) {
   float band = floor(colRow.y / 8.0);
   vec2 bandSalt = vec2(band, colRow.y);

   // this is per band
   float maxRunLength = 2.0 + 9.0 * rand(bandSalt * spice2);
   float lightDensity =  1.0 / (2.0 + 2.0 * rand(bandSalt * spice3) + 2.0 * rand(bandSalt * spice4));

   vec2 cellSalt = vec2(spice1, colRow.y);

   bool lit = false;
   float i = 0.0;
   do {
       vec2 cellSalt = vec2(i, colRow.y);
       float run = 1.0 + maxRunLength * rand(cellSalt * spice5);
       i += run;
       lit = lightDensity >= rand(cellSalt * spice6);
   } while (i <  colRow.x);

   return lit;
}

vec3 windowColor(bool lit, vec2 salt) {
    if (lit) {
        vec3 base = vec3(0.5);
        vec3 gray = vec3(0.25) * rand(salt + vec2(1.0, 6.0));
        vec3 color = vec3(rand(salt * 4.0), rand(salt * 2.0), rand(salt * 3.0)) * 0.15;
        return base + gray + color;
    } else {
       return  vec3(0.2) * rand(salt);
    }
}

float windowAlpha(vec2 offset, float left, float bottom, float top, int features, vec2 salt) {
    if ((features & 1) != 0 && 
        isVerticalSplit(offset, left)) return 0.3;
    
    if ((features & 2) != 0 && 
        isHorizontalSplit(offset, bottom, top)) return 0.3;
    
    float blindStart = (1.0 - rand(salt * spice1) * rand(salt * spice1)) * 
                       (${uWindowDim}.y - bottom - top);
    if ((features & 4) != 0 && blindStart < offset.y - bottom) return 0.3;
    
    if ((features & 8) != 0) {           
        salt.x += gl_FragCoord.x - offset.x + featureStart(offset.x, salt);
        // Note the salt is not feature specific instead of window specific
        return furnitureAlpha(offset, salt);
    }
    
    return 1.0;
}

// feature:
// bit 0: vertical split
// bit 1: horizontal split
// bit 2: blinds
// bit 3: furniture
// bit 4: always lit
void main() {
    vec2 colRow = floor(gl_FragCoord.xy / ${uWindowDim});
    
    vec2 offset = mod(gl_FragCoord.xy, ${uWindowDim});
    vec2 bottomLeft = gl_FragCoord.xy - offset;
    vec2 salt = bottomLeft + vec2(0.123, 0.456);
    // The salt is now the same for all pixels falling into the window
    
    float left = ${uWindowFrame}.x;
    float bottom = ${uWindowFrame}.y;
    float top =${uWindowFrame}.z;
    
    vec3 color = ${uColor};
    if (isWindow(offset, left, bottom, top)) {
        bool lit = (${uFeatures} & 16) != 0 || isLit(colRow);
        color = windowColor(lit, salt) *
                windowAlpha(offset, left, bottom, top, ${uFeatures}, salt);
    }
    ${oFragColor}.rgb = color; 
    ${oFragColor}.a = 1.0;
}
 """
  ]);

final ShaderObject edgeDetectionVertexShader = ShaderObject("edgeDetectionV")
  ..AddAttributeVars([aPosition, aNormal])
  ..AddVaryingVars([vNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..SetBodyWithMain([StdVertexBody, StdVertexNormalForward]);

final ShaderObject edgeDetectionFragmentShader = ShaderObject("edgeDetectionF")
  ..AddVaryingVars([vNormal])
  ..AddUniformVars([uTexture])
  ..SetBodyWithMain([
    """
        vec3 n = normalize(${vNormal});
        float z = clamp( 0., 1., gl_FragCoord.w * 10. );
        ${oFragColor} = vec4(0.5 * ( 1.0 + n.x ), 
                                 0.5 * ( 1.0 + n.y ), 
                                 z, 
                                 1.0);
        """
  ]);

//
// Preparation Shader
//

final ShaderObject sketchPrepVertexShader = ShaderObject("preparationV")
  ..AddAttributeVars([
    aPosition,
    aNormal,
    aTexUV
  ]) // added aTexUV for compatibility with final shader
  ..AddVaryingVars([vNormal])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBody([
    """
void main(void) {
    {
      vec3 p = ${aPosition};
      gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(p, 1);
    }
    {
      // Normal does not have to be accurate 
      vec3 n = ${aNormal};
      ${vNormal} = normalize(n);
    }
}
"""
  ]);

final ShaderObject sketchPrepFragmentShader = ShaderObject("preparationF")
  ..AddVaryingVars([vNormal])
  ..SetBodyWithMain([
    """
  ${oFragColor} = vec4(${vNormal}, gl_FragCoord.w);
  """
  ]);

// Sketch shader based on:
// http://www.thomaseichhorn.de/npr-sketch-shader-vvvv/
// https://github.com/spite/npr-shading

//
// Final Shader
//

final ShaderObject sketchVertexShader = ShaderObject("finalV")
  ..AddAttributeVars([aPosition, aNormal, aTexUV])
  ..AddVaryingVars([vNormal, vTexUV, vPosition])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBody([
    """ 
void main(void) {
   {
     vec3 p = ${aPosition};
     gl_Position = ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(p, 1);
   }
   {
      vec4 n =  ${uPerspectiveViewMatrix} * ${uModelMatrix} * vec4(${aNormal}, 0);
       ${vNormal} = normalize(n).xyz;
   }
   ${vTexUV} = ${aTexUV};
   ${vPosition} = gl_Position.xyz;
}
"""
  ]);

final ShaderObject sketchFragmentShader = ShaderObject("finalF")
  ..AddVaryingVars([vColor, vNormal, vTexUV, vPosition])
  ..AddUniformVars(
      [uTexture, uTexture2, uLightDescs, uLightTypes, uShininess, uEyePosition])
  ..SetBody([
    """
 float Edge(sampler2D t, ivec2 p) {
      vec4 hEdge = vec4(0.0);
      hEdge -= texelFetch(t, ivec2(p.x - 1, p.y - 1), 0) * 1.0;
      hEdge -= texelFetch(t, ivec2(p.x - 1, p.y    ), 0) * 2.0;
      hEdge -= texelFetch(t, ivec2(p.x - 1, p.y + 1), 0) * 1.0;
      hEdge += texelFetch(t, ivec2(p.x + 1, p.y - 1), 0) * 1.0;
      hEdge += texelFetch(t, ivec2(p.x + 1, p.y    ), 0) * 2.0;
      hEdge += texelFetch(t, ivec2(p.x + 1, p.y + 1), 0) * 1.0;
      vec4 vEdge = vec4(0.0);
      vEdge -= texelFetch(t, ivec2(p.x - 1, p.y - 1), 0) * 1.0;
      vEdge -= texelFetch(t, ivec2(p.x    , p.y - 1), 0) * 2.0;
      vEdge -= texelFetch(t, ivec2(p.x + 1, p.y - 1), 0) * 1.0;
      vEdge += texelFetch(t, ivec2(p.x - 1, p.y + 1), 0) * 1.0;
      vEdge += texelFetch(t, ivec2(p.x    , p.y + 1), 0) * 2.0;
      vEdge += texelFetch(t, ivec2(p.x + 1, p.y + 1), 0) * 1.0;
      vec3 edge = sqrt((hEdge.rgb * hEdge.rgb) + (vEdge.rgb * vEdge.rgb));
      return length(edge);
 }
 
 void main(void) {
   ColorComponents acc = CombinedLight(${vPosition},
                                       ${vNormal},
                                       ${uEyePosition},
                                       ${uLightDescs},
                                       ${uLightTypes},
                                       ${uShininess});
                                     
   float edge = Edge(${uTexture2}, ivec2(gl_FragCoord.xy));
   vec4 info = texelFetch(${uTexture2}, ivec2(gl_FragCoord.xy), 0);
   if (edge > 0.3) {
       //${oFragColor}.rgb = vec3(0.0); 
       ${oFragColor}.rgb = vec3(0.5 - edge); 
      // ${oFragColor}.rgb = vec3(edge / (100.0 * info.w));
     return;
   } 
     
   ${oFragColor}.rgb = texture(${uTexture}, ${vTexUV}).rgb * 0.5 + 
                       acc.diffuse +
                       acc.specular;
 }
   """
  ], prolog: [
    StdLibShader
  ]);

const String _WireframeF = """
// the 3 vertices of a Face3 (w == 0) have the centers:
// (1, 0, 0, 0)) 
// (0, 1, 0, 0)
// (0, 0, 1, 0)
float edgeFactorFace3(vec3 center) {
    vec3 d = fwidth(center);
    vec3 a3 = smoothstep(vec3(0.0), d * ${uWidth}, center);
    return min(min(a3.x, a3.y), a3.z);
}

// the 4 vertices of a Face4 (w == 1) have the centers:
// (1, 0, 0, 1) 
// (1, 1, 0, 1)
// (0, 1, 0, 1)
// (0, 0, 0, 1)
float edgeFactorFace4(vec2 center) {
    vec2 d = fwidth(center);
    vec2 a2 = smoothstep(vec2(0.0), d * ${uWidth}, center);
    return min(a2.x, a2.y);
}

void main() {
    float q;
    if (${vCenter}.w == 0.0) {
        q = edgeFactorFace3(${vCenter}.xyz);
    } else {
        q = min(edgeFactorFace4(${vCenter}.xy),
                edgeFactorFace4(1.0 - ${vCenter}.xy));
    }
    ${oFragColor} = mix(${uColorAlpha}, ${uColorAlpha2}, q);
}
""";

final ShaderObject wireframeVertexShader = ShaderObject("WireframeV")
  ..AddAttributeVars([aPosition, aCenter])
  ..AddVaryingVars([vCenter])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..SetBodyWithMain([StdVertexBody, "${vCenter} = ${aCenter};"]);

final ShaderObject wireframeFragmentShader = ShaderObject("WireframeF")
  ..AddVaryingVars([vCenter])
  ..AddUniformVars([uColorAlpha, uColorAlpha2, uWidth])
  ..SetBody([_WireframeF]);

final ShaderObject texturedVertexShader = ShaderObject("Textured")
  ..AddAttributeVars([aPosition, aTexUV])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vTexUV])
  ..SetBody([StdVertexShaderWithTextureForwardString]);

final ShaderObject texturedFragmentShader = ShaderObject("TexturedF")
  ..AddVaryingVars([vTexUV])
  ..AddUniformVars([uColor, uTexture])
  ..SetBodyWithMain([
    "${oFragColor} = texture(${uTexture}, ${vTexUV}) + vec4( ${uColor}, 0.0 );"
  ]);

final ShaderObject multiColorVertexShader = ShaderObject("MultiColorVertexColorV")
  ..AddAttributeVars([aPosition, aColor])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain([
    StdVertexBody,
    "${vColor} = ${aColor};",
  ], prolog: [
    StdLibShader
  ]);

final ShaderObject multiColorFragmentShader = ShaderObject("MultiColorVertexColorF")
  ..AddVaryingVars([vColor])
  ..SetBodyWithMain(["${oFragColor} = vec4( ${vColor}, 1.0 );"]);
