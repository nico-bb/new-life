#version 450 core
in VS_OUT {
    vec2 texCoord;
} frag;

out vec4 finalColor;

layout (std140, binding = 0) uniform ContextData {
    mat4 projView;
    mat4 matProj;
    mat4 matView;
    vec3 viewPosition;
    float time;
    float dt;
};

struct Light {
    vec4 position;
    vec4 color;

    float linear;
    float quadratic;
    
    uint mode;
    uint padding;
};
const uint DIRECTIONAL_LIGHT = 0;
const uint POINT_LIGHT = 1;
const int MAX_LIGHTS = 32;
const int MAX_SHADOW_MAPS = 1;
const int MAXS_SHADOW_CASCADE = 3;
layout (std140, binding = 1) uniform LightingContext {
    Light lights[MAX_LIGHTS];
    // ID of the lights used for shadow mapping in the x component
    // Number of cascade in the y component
    uvec4 shadowCasters[MAX_SHADOW_MAPS];
    // Space matrices of the lights used for shadow mapping
    mat4 matLightSpaces[MAX_SHADOW_MAPS][MAXS_SHADOW_CASCADE];
    // FIXME: Temporary uvec4 for padding related reasons
    vec4 cascadesDistances[MAX_SHADOW_MAPS];
    vec4 ambient;                            // .rgb for the color and .a for the intensity
    uint lightCount;
    uint shadowCasterCount;
};

struct Material {
    vec4 color;
    float roughness;
    float metallicness;
    vec2 _padding;
};


#define MATERIAL_CACHE_CAP 124
layout (std140, binding = 2) uniform MaterialCache {
    Material materials[MATERIAL_CACHE_CAP];
    uint count;
};

struct LightDesc {
    Light light;
    vec3 normal;
    vec3 lightDir;
    vec3 viewDir;
    vec3 halfwayDir;
    vec3 nViewPosition;
};

#define LOC_6 (6 + MAX_SHADOW_MAPS * MAXS_SHADOW_CASCADE)

layout (location = 0)     uniform sampler2D bufferedPosition;
layout (location = 1)     uniform sampler2D bufferedNormal;
layout (location = 2)     uniform sampler2D bufferedAlbedo;
layout (location = 3)     uniform sampler2D bufferedMaterial;
layout (location = 4)     uniform sampler2D bufferedDepth;
layout (location = 5)     uniform sampler2D shadowMaps[MAX_SHADOW_MAPS * MAXS_SHADOW_CASCADE];
layout (location = LOC_6) uniform vec2 shadowOffsets[16];

vec3 diffuseDirectional( LightDesc desc);
vec3 specularDirectional( LightDesc desc );
vec3 fresnelApproximation( LightDesc desc, vec3 specularClr );
float computeShadowValue(int casterIndex, vec3 position, vec3 normal);
float filterShadowMap(uint shadowMapIndex, vec3 shadowCoord, float bias);
vec3 applyAtmosphericFog(in vec3 texelClr, float dist, vec3 viewDir, vec3 lightDir);

void main() {
    vec4 p = texture(bufferedPosition, frag.texCoord).rgba;
    vec3 position = p.rgb;
    vec3 normal = texture(bufferedNormal, frag.texCoord).rgb;
    vec3 albedo = texture(bufferedAlbedo, frag.texCoord).rgb;
    float distance = length(position - viewPosition);

    if (p.a <= 0.05) {
        discard;
    }

    uint materialId = uint(
        texture(bufferedMaterial, frag.texCoord).r * MATERIAL_CACHE_CAP + 0.5);
    Material material = materials[materialId];
    if (materialId == 0) {
        finalColor = vec4(1.0, 1.0, 0.0, 0.0);
        return;
    }

    vec3 ambient = ambient.xyz * ambient.a;

    float shadowValue = 0.0;
    for (int i = 0; i < shadowCasterCount; i += 1) {
        shadowValue += computeShadowValue(i, position, normal);
    }
    
    vec3 F0 = mix(vec3(0.04), albedo, material.metallicness);
    vec3 diffuse = vec3(0);
    vec3 specular = vec3(0);
    LightDesc desc;
    desc.viewDir = normalize(viewPosition - position);
    desc.nViewPosition = normalize(viewPosition);
    desc.normal = normal;
    for (int i = 0; i < lightCount; i += 1) {
        Light light = lights[i];
        desc.light = light;
        desc.lightDir = normalize(desc.light.position.xyz);
        desc.halfwayDir = normalize(desc.lightDir + desc.viewDir);

        diffuse += diffuseDirectional(desc);
        vec3 lSpec = specularDirectional(desc);
        vec3 fSpec = fresnelApproximation(desc, F0);
        specular += fSpec * lSpec;
    }

    vec3 result = (ambient + ((1.0 - shadowValue) * (diffuse + specular))) * albedo; 
    result = applyAtmosphericFog(result, distance, vec3(0), vec3(0));
    finalColor = vec4(result, 1.0);
}

vec3 diffuseDirectional( LightDesc desc ) {
    float diffuse = max(dot(desc.lightDir, desc.normal), 0.0);
    return diffuse * desc.light.color.rgb;
}

vec3 specularDirectional( LightDesc desc ) {
    float specular = max(dot(desc.normal, desc.halfwayDir), 0.0);
    specular = pow(specular, 32.0);
    return specular * desc.light.color.rgb;
}

vec3 fresnelApproximation( LightDesc desc, vec3 F0 ) {
    const float fPower = 5.0;

    const float cosTheta = clamp(dot(desc.halfwayDir, desc.nViewPosition), 0.0, 1.0);
    float fresnelFactor = pow(1.0 - cosTheta, fPower);

    return F0 + (1.0 - F0) * fresnelFactor;
}

float computeShadowValue(int casterIndex, vec3 position, vec3 normal) {

    const uint lightID = shadowCasters[casterIndex].x;
    const uint cascadeCount = shadowCasters[casterIndex].y;
    const Light light = lights[lightID];
    const vec3 lightDir = normalize(light.position.xyz);
    float bias = 0.0002 * (1.0 - dot(normal, lightDir));
	bias = max(bias, 0.0002);
    
    vec4 viewSpacePosition = matView * vec4(position, 1.0);
    for (int i = 0; i < cascadeCount; i += 1) {
        const uint shadowMapIndex = casterIndex * MAXS_SHADOW_CASCADE + i;
        vec4 viewCoord = matView * vec4(position, 1.0);
        vec4 shadowCoord = matLightSpaces[casterIndex][i] * vec4(position, 1.0);
        vec3 nShadowCoord = shadowCoord.xyz / shadowCoord.w;
        nShadowCoord = nShadowCoord * 0.5 + 0.5;
        if (i == cascadeCount - 1 || abs(viewCoord.z) < cascadesDistances[casterIndex][i]) {
            return filterShadowMap(shadowMapIndex, nShadowCoord, bias);
        }
    }

    return 0.0;
}

float filterShadowMap(uint shadowMapIndex, vec3 shadowCoord, float bias) {
    const float maxShadowValue = 0.9;

    float result = 0.0;
    const vec2 texelSize = 1.0 / textureSize(shadowMaps[shadowMapIndex], 0);
    for (int i = 0; i < 4; i += 1) {
        const vec2 offset = shadowOffsets[i];
        const vec2 filterCoord = shadowCoord.xy + offset * texelSize;
        const float filterDepth = texture(shadowMaps[shadowMapIndex], filterCoord).r;
        result += shadowCoord.z - bias > filterDepth ? 1.0 : 0.0;
    }
    result /= 4.0;

    if (result != 0.0 && result != 1.0) {
        for (int i = 4; i < 16; i += 1) {
            const vec2 offset = shadowOffsets[i];
            const vec2 filterCoord = shadowCoord.xy + offset * texelSize;
            const float filterDepth = texture(shadowMaps[shadowMapIndex], filterCoord).r;
            result += shadowCoord.z - bias > filterDepth ? 1.0 : 0.0;
        }
        result /= 12.0;
    }
    result = min(result, maxShadowValue);

    return result;
}

vec3 applyAtmosphericFog(in vec3 texelClr, float dist, vec3 viewDir, vec3 lightDir) {
    const vec3 fogClr = vec3(0.5, 0.6, 0.7);
    const float fogDistNear = 50.0;
    const float fogDistFarBlend = 30.0;
    const float fogDensity = 0.005;
    const float fogNearDensity = 5.0;

    float fogNearContribution = max((1.0 - pow((dist / fogDistNear), fogNearDensity)), 0.0);
    float fogFarContribution = (exp(-dist * fogDensity));
    float fogContribution = dist < fogDistFarBlend ? fogNearContribution : min(fogNearContribution, fogFarContribution);
    fogContribution = 1 - fogContribution;
    
    vec3 result = mix(texelClr, fogClr, fogContribution);
    return result;
}