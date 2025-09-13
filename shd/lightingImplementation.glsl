// NOTE: lighting implementation expects the 'Light' struct to exist as a uniform to the shader
struct LightCalculation {
    vec3 lightDot;
    vec3 specular;
};
LightCalculation lightCalculation(vec3 normal, vec3 viewDir) {
    LightCalculation calc;
    calc.lightDot = vec3(0.0);
    calc.specular = vec3(0.0);
    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (lights[i].enabled == 1) {
            vec3 light = vec3(0.0);
            if (lights[i].type == LIGHT_DIRECTIONAL) {
                light = -normalize(lights[i].target - lights[i].position);
            }
            if (lights[i].type == LIGHT_POINT) {
                light = normalize(lights[i].position - fragPos);
            }
            float NdotL = max(dot(normal, light), 0.0);
            calc.lightDot += lights[i].color.rgb * NdotL;
            float specCo = 0.0;
            if (NdotL > 0.0) {
                specCo = pow(max(0.0, dot(viewDir, reflect(-(light), normal))), 16.0); // 16 refers to shine
            }
            calc.specular += specCo;
        }
    }
    return calc;
}
