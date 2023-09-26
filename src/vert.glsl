#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 norm;
layout (location = 3) in vec4 col;

out vec3 out_norm;
out vec2 out_uv;

uniform mat4 _P;
uniform mat4 _V;
uniform mat4 _M;

vec4 local2clip(vec3 localPos)
{
 	return _P * _V * _M * vec4(localPos, 1.0);
}

void main()
{
    vec3 p = pos;
    gl_Position = local2clip(pos);
    out_norm = norm;
    out_uv = uv;
}