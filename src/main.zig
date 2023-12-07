const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
});

const HEIGHT = 600;
const WIDTH = 600;
const FPS = 60;
const DT_TIME: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

const BACKGROUND_COLOR = 0x181818FF;
const PLAYER_COLOR = 0x523261FF;
const PLAYER_RADIUS = 0.5 * ONE_METER;
const ONE_METER = 100;
const GRAVITY = 2 * ONE_METER;

const Vec2f = struct {
    x: f32,
    y: f32,

    fn add(self: Vec2f, other: Vec2f) void {
        self.x += other.x;
        self.y += other.y;
    }
};

const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    fn SDL_Rect(self: Rect) c.SDL_Rect {
        return c.SDL_Rect{
            .h = @as(i32, @intFromFloat(self.h)),
            .w = @as(i32, @intFromFloat(self.w)),
            .x = @as(i32, @intFromFloat(self.x)),
            .y = @as(i32, @intFromFloat(self.y)),
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
};

var ball_dirx: f32 = 0;
var ball_jumping: bool = false;

var ball = Body{
    .rect = Rect{
        .x = WIDTH / 2,
        .y = 0,
        .w = 0.5 * ONE_METER,
        .h = 0.5 * ONE_METER,
    },
    .vel = .{ .x = 6 * ONE_METER, .y = 0 },
    .aceleration = 0,
};

var running: bool = true;

fn ballHorizontalCollision() void {
    const new_velx = ball.vel.x * DT_TIME * ball_dirx; // todo: remover ball_dirx
    const new_x: f32 = math.clamp(ball.rect.x + new_velx, ball.rect.h, WIDTH - ball.rect.h);
    ball.rect.x = new_x;
}

fn ballVerticalCollission() void {
    const new_vely = DT_TIME * (ball.vel.y + ball.aceleration);
    const new_y: f32 = math.clamp(ball.rect.y + new_vely, ball.rect.h, HEIGHT - ball.rect.h);

    if (new_y == HEIGHT - ball.rect.h) {
        ball.aceleration = 0;
        ball.vel.y = 0;
        ball_jumping = false;
    } else {
        ball.vel.y = new_vely;
        ball.addAcceleration(GRAVITY);
    }

    ball.rect.y = new_y;
}

fn makeRect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .h = @as(i32, @intFromFloat(h)),
        .w = @as(i32, @intFromFloat(w)),
        .x = @as(i32, @intFromFloat(x)),
        .y = @as(i32, @intFromFloat(y)),
    };
}

fn setColor(renderer: *c.SDL_Renderer, color: u32) void {
    const r = @as(u8, @truncate((color >> (8 * 3)) & 0xFF));
    const g = @as(u8, @truncate((color >> (8 * 2)) & 0xFF));
    const b = @as(u8, @truncate((color >> (8 * 1)) & 0xFF));
    const a = @as(u8, @truncate((color >> (8 * 0)) & 0xFF));
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn cleanUp(renderer: *c.SDL_Renderer, color: u32) void {
    setColor(renderer, color);
    _ = c.SDL_RenderClear(renderer);
}

fn updateScene() void {
    ballHorizontalCollision();
    ballVerticalCollission();
}

fn renderScene(renderer: *c.SDL_Renderer) void {
    _ = c.filledCircleColor(renderer, @as(i16, @intFromFloat(ball.rect.x)), @as(i16, @intFromFloat(ball.rect.y)), @as(i16, @intFromFloat(ball.rect.h)), PLAYER_COLOR);
}

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
            if (!ball_jumping) {
                ball_jumping = true;
                ball.addAcceleration(-30 * ONE_METER);
            }
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
        renderScene(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
