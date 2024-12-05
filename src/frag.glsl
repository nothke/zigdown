#version 330 core
out vec4 FragColor;

in vec3 out_norm;
in vec2 out_uv;

uniform vec4 _Color;
uniform sampler2D _Texture;

void main()
{
    vec3 n = out_norm;
    vec3 l = normalize(vec3(0.5, 0.5, -0.5));
    float light = -dot(n, l);

    vec4 tex = texture(_Texture, out_uv);

    vec3 diffuse = vec3(1.0, 1.0, 1.0);
    vec3 color = tex.rgb * diffuse * light * 2;

    FragColor = vec4(color, 1.0) * _Color;

    //FragColor = tex * _Color;
} 