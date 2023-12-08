const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
});

const overlaps = c.SDL_HasIntersection;

const HEIGHT = 600;
const WIDTH = 600;
const FPS = 60;
const DT_TIME: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

const BACKGROUND_COLOR = 0x181818FF;
var PLAYER_COLOR: u32 = 0x52774aFF;
const WALL_COLOR = 0x3676c9FF;
const ONE_METER = 100;
const GRAVITY = 1 * ONE_METER;
const BALL_FORCE = -2 * ONE_METER;
const MAX_ACELERATION = -5 * ONE_METER;

const Vec2f = @Vector(2, f32);
//     x: f32,
//     y: f32,
//     vec: @Vector(2, f32),

//     fn init(x: f32, y: f32) Vec2f {
//         return Vec2f{.x = x,}
//     }
//     fn toVector(self: Vec2f) @Vector(2, f32) {
//         return @Vector(2, f32)
//     }
//     fn add(self: *Vec2f, other: Vec2f) void {
//         self.x += other.x;
//         self.y += other.y;
//     }

//     fn length(self: Vec2f) f32 {
//         math.sqrt(self.x * self.x + self.y * self.y);
//     }

//     fn subVec(self: Vec2f, other: Vec2f) Vec2f {
//         return .{ .x = self.x - other.x, .y = self.y - other.y };
//     }

//     fn addVec(self: Vec2f, other: Vec2f) Vec2f {
//         return .{ .x = self.x + other.x, .y = self.y + other.y };
//     }

//     fn negative(self: Vec2f) Vec2f {
//         return .{ .x = -self.x, .y = -self.y };
//     }
// };

const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    fn SDL_Rect(self: Rect) c.SDL_Rect {
        return c.SDL_Rect{
            .x = @as(i16, @intFromFloat(self.x)),
            .y = @as(i16, @intFromFloat(self.y)),
            .w = @as(i16, @intFromFloat(self.w)),
            .h = @as(i16, @intFromFloat(self.h)),
        };
    }
};

const Body = struct {
    rect: Rect,
    vel: Vec2f,
    aceleration: f32,

    fn addAcceleration(self: *Body, amount: f32) void {
        self.aceleration += amount;
    }

    fn addVelocity(self: *Body, vel: Vec2f) void {
        self.vel.add(vel);
    }

    fn moveY(self: *Body, upper_limit: f32, lower_limit: f32) void {
        const new_vely = DT_TIME * (self.vel[1] + self.aceleration);
        const new_y: f32 = math.clamp(self.rect.y + new_vely, upper_limit, lower_limit);

        if (new_y == lower_limit) {
            self.aceleration = 0;
            self.vel[1] = 0;
            self.rect.y = lower_limit;
            return;
        }

        self.addAcceleration(GRAVITY);
        self.vel[1] = new_vely;
        self.rect.y = new_y;
    }
};

var ball_dirx: f32 = 0;

var ball = Body{
    .rect = .{
        .x = WIDTH / 2,
        .y = HEIGHT / 2,
        .w = 0.5 * ONE_METER,
        .h = 0.5 * ONE_METER,
    },
    .vel = .{ 6 * ONE_METER, 0 },
    .aceleration = 0,
};

var wall = Body{
    .rect = .{
        .x = WIDTH - 200,
        .y = HEIGHT - 500,
        .w = 200,
        .h = 500,
    },
    .vel = .{ 3 * ONE_METER, 0 },
    .aceleration = 0,
};

fn ballHorizontalCollision() void {
    const new_velx = ball.vel[0] * DT_TIME * ball_dirx; // todo: remover ball_dirx
    const new_x: f32 = math.clamp(ball.rect.x + new_velx, ball.rect.h, WIDTH - ball.rect.h);
    ball.rect.x = new_x;
}

fn ballVerticalCollission() void {
    ball.moveY(ball.rect.h, HEIGHT - ball.rect.h);
}

fn swapColor(color: u32) u32 {
    const r = color >> (8 * 0) & 0xFF;
    const g = color >> (8 * 1) & 0xFF;
    const b = color >> (8 * 2) & 0xFF;
    const a = color >> (8 * 3) & 0xFF;
    return (r << 8 * 3) | (g << 8 * 2) | (b << 8 * 1) | a;
}

fn setColor(renderer: *c.SDL_Renderer, color: u32) void {
    const r = @as(u8, @truncate(color >> (8 * 3)));
    const g = @as(u8, @truncate(color >> (8 * 2)));
    const b = @as(u8, @truncate(color >> (8 * 1)));
    const a = @as(u8, @truncate(color >> (8 * 0)));
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn cleanUp(renderer: *c.SDL_Renderer, color: u32) void {
    setColor(renderer, color);
    _ = c.SDL_RenderClear(renderer);
}

fn drawCircle(renderer: *c.SDL_Renderer, x: f32, y: f32, radius: f32, color: u32) !void {
    const swaped_color = swapColor(color);
    const c_result = c.filledCircleColor(renderer, @as(i16, @intFromFloat(x)), @as(i16, @intFromFloat(y)), @as(i16, @intFromFloat(radius)), swaped_color);
    if (c_result != 0) {
        c.SDL_Log("error drawing circle {s}", c.SDL_GetError());
        return error.drawingError;
    }
}

fn drawRect(renderer: *c.SDL_Renderer, rect: Rect, color: u32) !void {
    setColor(renderer, color);
    const sdl_rect = rect.SDL_Rect();
    const c_result = c.SDL_RenderFillRect(renderer, &sdl_rect);
    if (c_result != 0) {
        c.SDL_Log("error drawing rect {any} {s}", sdl_rect, c.SDL_GetError());
        return error.drawingError;
    }
    setColor(renderer, BACKGROUND_COLOR);
}

fn vecClamp(val: Vec2f, lower: Vec2f, upper: Vec2f) @TypeOf(val, lower, upper) {
    return @max(lower, @min(val, upper));
}

fn circularCollision(radius: f32, center: Vec2f, collider: Rect) bool {
    const aabb_half_extends = Vec2f{ collider.w / 2, collider.h / 2 };
    const aabb_center = Vec2f{ collider.x + aabb_half_extends[0], collider.y + aabb_half_extends[1] };
    var difference: Vec2f = center - aabb_center;
    const clamped = vecClamp(difference, -aabb_half_extends, aabb_half_extends);
    const closest = aabb_center + clamped;
    difference = closest - center;
    const vec_len = math.sqrt(difference[0] * difference[0] + difference[1] * difference[1]);
    return vec_len < radius;
}

fn updateScene() void {
    if (circularCollision(ball.rect.h, Vec2f{ ball.rect.x, ball.rect.y }, wall.rect)) {
        PLAYER_COLOR = ~PLAYER_COLOR | 0x000000FF;
    }
    ballHorizontalCollision();
    ballVerticalCollission();
}

fn renderScene(renderer: *c.SDL_Renderer) !void {
    try drawCircle(renderer, ball.rect.x, ball.rect.y, ball.rect.h, PLAYER_COLOR);
    try drawRect(renderer, wall.rect, WALL_COLOR);
}

var running: bool = true;
pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_EVERYTHING) != 0) {
        c.SDL_Log("cannot init SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Space Zig", 0, 0, WIDTH, HEIGHT, 0) orelse {
        c.SDL_Log("cannot create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("cannot create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    else => {},
                }
            }
        }

        if (keyboard[c.SDL_SCANCODE_SPACE] != 0) {
            if (ball.aceleration > MAX_ACELERATION) ball.addAcceleration(BALL_FORCE);
        }
        ball_dirx = 0;
        if (keyboard[c.SDL_SCANCODE_A] != 0) {
            ball_dirx = -1;
        }
        if (keyboard[c.SDL_SCANCODE_D] != 0) {
            ball_dirx = 1;
        }

        cleanUp(renderer, BACKGROUND_COLOR);
        updateScene();

        try renderScene(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
        errdefer running = false;
    }
}
