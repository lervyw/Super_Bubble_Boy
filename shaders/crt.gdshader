shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float screen_width = 320.0;
uniform float screen_height = 180.0;

uniform float barrel_power : hint_range(0.5, 2.0) = 1.1;
uniform float color_bleeding : hint_range(0.0, 2.0) = 1.2;
uniform float bleeding_range_x : hint_range(1.0, 8.0) = 3.0;
uniform float bleeding_range_y : hint_range(1.0, 8.0) = 3.0;
uniform float lines_distance : hint_range(1.0, 8.0) = 4.0;
uniform float scan_size : hint_range(0.5, 4.0) = 2.0;
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.7;
uniform float lines_velocity : hint_range(0.0, 100.0) = 20.0;

vec2 distort(vec2 p)
{
	float angle = p.y / p.x;
	float theta = atan(p.y, p.x);
	float radius = pow(length(p), barrel_power);

	p.x = radius * cos(theta);
	p.y = radius * sin(theta);

	return 0.5 * (p + vec2(1.0, 1.0));
}

void get_color_bleeding(inout vec4 current_color, inout vec4 color_left)
{
	current_color = current_color * vec4(color_bleeding, 0.5, 1.0 - color_bleeding, 1.0);
	color_left = color_left * vec4(1.0 - color_bleeding, 0.5, color_bleeding, 1.0);
}

void get_color_scanline(vec2 uv, inout vec4 c, float time)
{
	float line_row = floor((uv.y * screen_height / scan_size) + mod(time * lines_velocity, lines_distance));
	float n = 1.0 - ceil((mod(line_row, lines_distance) / lines_distance));
	c = c - n * c * (1.0 - scanline_alpha);
	c.a = 1.0;
}

void fragment()
{
	vec2 xy = SCREEN_UV * 2.0;
	xy.x -= 1.0;
	xy.y -= 1.0;

	float d = length(xy);
	if (d < 1.5)
	{
		xy = distort(xy);
	}
	else
	{
		xy = SCREEN_UV;
	}

	float pixel_size_x = 1.0 / screen_width * bleeding_range_x;
	float pixel_size_y = 1.0 / screen_height * bleeding_range_y;
	vec4 color_left = texture(screen_texture, xy - vec2(pixel_size_x, pixel_size_y));
	vec4 current_color = texture(screen_texture, xy);
	get_color_bleeding(current_color, color_left);
	vec4 c = current_color + color_left;
	get_color_scanline(xy, c, TIME);
	COLOR = c;
}
