#version 330 core
out vec4 FragColor;

in vec2 out_uv;

uniform sampler2D _Texture;
uniform sampler2D _Texture2;

void main()
{
    vec4 tex1 = texture(_Texture, out_uv);
    vec4 tex2 = texture(_Texture2, out_uv);
    FragColor = mix(tex1, tex2, 0.8);
} 