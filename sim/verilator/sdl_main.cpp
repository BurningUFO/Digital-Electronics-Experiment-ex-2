#include <SDL2/SDL.h>
#include <verilated.h>

#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <string>

#include "Vgame_console_top.h"

namespace {

constexpr int kVisibleWidth = 640;
constexpr int kVisibleHeight = 480;
constexpr int kDefaultScale = 2;

#ifdef SIM_SHORT_BLANK
constexpr int kHSyncBackPorch = 4 + 2;
constexpr int kVSyncBackPorch = 1 + 1;
#else
constexpr int kHSyncBackPorch = 96 + 48;
constexpr int kVSyncBackPorch = 2 + 33;
#endif

struct Options {
    int scale = kDefaultScale;
    int max_frames = -1;
    int frame_skip = 0;
    bool throttle = true;
    bool present_every_frame = false;
};

bool parse_int_arg(const char* text, int* out) {
    char* end = nullptr;
    long value = std::strtol(text, &end, 10);
    if (end == text || *end != '\0') {
        return false;
    }
    *out = static_cast<int>(value);
    return true;
}

Options parse_options(int argc, char** argv) {
    Options options;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--frames" && i + 1 < argc) {
            parse_int_arg(argv[++i], &options.max_frames);
        } else if (arg == "--scale" && i + 1 < argc) {
            parse_int_arg(argv[++i], &options.scale);
            if (options.scale < 1) {
                options.scale = 1;
            }
        } else if (arg == "--no-throttle") {
            options.throttle = false;
        } else if (arg == "--frame-skip" && i + 1 < argc) {
            parse_int_arg(argv[++i], &options.frame_skip);
            if (options.frame_skip < 0) {
                options.frame_skip = 0;
            }
        } else if (arg == "--present-every-frame") {
            options.present_every_frame = true;
        } else if (arg == "--help" || arg == "-h") {
            std::printf("Usage: Vgame_console_top [--scale N] [--frames N] [--frame-skip N] [--no-throttle] [--present-every-frame]\n");
            std::exit(0);
        }
    }
    return options;
}

uint32_t rgb444_to_argb(uint8_t r, uint8_t g, uint8_t b) {
    uint8_t rr = static_cast<uint8_t>((r & 0x0f) * 17);
    uint8_t gg = static_cast<uint8_t>((g & 0x0f) * 17);
    uint8_t bb = static_cast<uint8_t>((b & 0x0f) * 17);
    return 0xff000000u | (static_cast<uint32_t>(rr) << 16) |
           (static_cast<uint32_t>(gg) << 8) | static_cast<uint32_t>(bb);
}

class Ps2Keyboard {
public:
    void enqueue_make(uint8_t scan, bool extended) {
        if (extended) {
            enqueue_byte(0xe0);
        }
        enqueue_byte(scan);
    }

    void enqueue_break(uint8_t scan, bool extended) {
        if (extended) {
            enqueue_byte(0xe0);
        }
        enqueue_byte(0xf0);
        enqueue_byte(scan);
    }

    void drive(Vgame_console_top& top) {
        if (!active_ && bits_.empty()) {
            top.PS2_CLK = 1;
            top.PS2_DATA = 1;
            return;
        }

        if (!active_) {
            active_ = true;
            phase_ = Phase::HighBeforeFall;
            ticks_ = 0;
            current_bit_ = bits_.front();
            bits_.pop_front();
        }

        top.PS2_DATA = current_bit_ ? 1 : 0;

        switch (phase_) {
        case Phase::HighBeforeFall:
            top.PS2_CLK = 1;
            if (++ticks_ >= kHalfBitCycles) {
                ticks_ = 0;
                phase_ = Phase::LowSample;
            }
            break;
        case Phase::LowSample:
            top.PS2_CLK = 0;
            if (++ticks_ >= kHalfBitCycles) {
                ticks_ = 0;
                phase_ = Phase::HighAfterFall;
            }
            break;
        case Phase::HighAfterFall:
            top.PS2_CLK = 1;
            if (++ticks_ >= kInterBitCycles) {
                ticks_ = 0;
                active_ = false;
            }
            break;
        }
    }

private:
    enum class Phase {
        HighBeforeFall,
        LowSample,
        HighAfterFall,
    };

    static constexpr int kHalfBitCycles = 80;
    static constexpr int kInterBitCycles = 20;

    void enqueue_byte(uint8_t value) {
        bits_.push_back(false);
        bool odd = false;
        for (int i = 0; i < 8; ++i) {
            bool bit = ((value >> i) & 1u) != 0;
            bits_.push_back(bit);
            odd = odd ^ bit;
        }
        bits_.push_back(!odd);
        bits_.push_back(true);
    }

    std::deque<bool> bits_;
    bool active_ = false;
    bool current_bit_ = true;
    Phase phase_ = Phase::HighBeforeFall;
    int ticks_ = 0;
};

struct KeyMapping {
    uint8_t scan = 0;
    bool extended = false;
    bool valid = false;
};

KeyMapping map_ps2_key(SDL_Keycode key) {
    switch (key) {
    case SDLK_w: return {0x1d, false, true};
    case SDLK_a: return {0x1c, false, true};
    case SDLK_s: return {0x1b, false, true};
    case SDLK_d: return {0x23, false, true};
    case SDLK_SPACE: return {0x29, false, true};
    case SDLK_RETURN: return {0x5a, false, true};
    case SDLK_ESCAPE: return {0x76, false, true};
    case SDLK_j: return {0x3b, false, true};
    case SDLK_k: return {0x42, false, true};
    case SDLK_UP: return {0x75, true, true};
    case SDLK_DOWN: return {0x72, true, true};
    case SDLK_LEFT: return {0x6b, true, true};
    case SDLK_RIGHT: return {0x74, true, true};
    default: return {};
    }
}

void handle_key_event(const SDL_KeyboardEvent& key_event, Vgame_console_top& top,
                      Ps2Keyboard& ps2, uint16_t& switches) {
    bool pressed = key_event.type == SDL_KEYDOWN;
    if (pressed && key_event.repeat != 0) {
        return;
    }

    SDL_Keycode key = key_event.keysym.sym;

    switch (key) {
    case SDLK_F1:
        top.BTNU = pressed;
        return;
    case SDLK_F2:
        top.BTND = pressed;
        return;
    case SDLK_F3:
        top.BTNL = pressed;
        return;
    case SDLK_F4:
        top.BTNR = pressed;
        return;
    case SDLK_F5:
        top.BTNC = pressed;
        return;
    case SDLK_F6:
        if (pressed) switches ^= 0x0001;
        top.SW = switches;
        return;
    case SDLK_F7:
        if (pressed) switches ^= 0x0002;
        top.SW = switches;
        return;
    case SDLK_F8:
        if (pressed) switches ^= 0x0004;
        top.SW = switches;
        return;
    case SDLK_F12:
        top.CPU_RESETN = pressed ? 0 : 1;
        return;
    default:
        break;
    }

    KeyMapping mapping = map_ps2_key(key);
    if (!mapping.valid) {
        return;
    }

    if (pressed) {
        ps2.enqueue_make(mapping.scan, mapping.extended);
    } else {
        ps2.enqueue_break(mapping.scan, mapping.extended);
    }
}

bool poll_events(Vgame_console_top& top, Ps2Keyboard& ps2, uint16_t& switches) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_QUIT) {
            return false;
        }
        if (event.type == SDL_KEYDOWN || event.type == SDL_KEYUP) {
            handle_key_event(event.key, top, ps2, switches);
        }
    }
    return true;
}

void reset_design(Vgame_console_top& top, Ps2Keyboard& ps2) {
    top.CLK100MHZ = 0;
    top.CPU_RESETN = 0;
    top.PS2_CLK = 1;
    top.PS2_DATA = 1;
    top.SW = 0;
    top.BTNU = 0;
    top.BTND = 0;
    top.BTNL = 0;
    top.BTNR = 0;
    top.BTNC = 0;

    for (int i = 0; i < 64; ++i) {
        ps2.drive(top);
        top.CLK100MHZ = 0;
        top.eval();
        top.CLK100MHZ = 1;
        top.eval();
    }
    top.CPU_RESETN = 1;
}

} // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Options options = parse_options(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
        std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "Nexys Game Console Verilator",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        kVisibleWidth * options.scale,
        kVisibleHeight * options.scale,
        SDL_WINDOW_SHOWN);
    if (!window) {
        std::fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) {
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    }
    if (!renderer) {
        std::fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_Texture* texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        kVisibleWidth,
        kVisibleHeight);
    if (!texture) {
        std::fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    Vgame_console_top top;
    Ps2Keyboard ps2;
    uint16_t switches = 0;
    std::array<uint32_t, kVisibleWidth * kVisibleHeight> framebuffer{};
    framebuffer.fill(0xff000000u);

    reset_design(top, ps2);

    bool running = true;
    int frame_count = 0;
    int pixel_x = 0;
    int pixel_y = 0;
    bool prev_hs = true;
    bool prev_vs = true;
    uint64_t cycles = 0;
    uint64_t last_present_ticks = SDL_GetTicks64();
    int skip_counter = 0;
    bool capturing = true;

    while (running && !Verilated::gotFinish()) {
        ps2.drive(top);

        top.CLK100MHZ = 0;
        top.eval();
        top.CLK100MHZ = 1;
        top.eval();
        ++cycles;

        bool hs = top.VGA_HS != 0;
        bool vs = top.VGA_VS != 0;
        bool hsync_start = prev_hs && !hs;
        bool vsync_start = prev_vs && !vs;

        if (vsync_start) {
            pixel_y = -kVSyncBackPorch;
        }
        if (hsync_start) {
            pixel_x = -kHSyncBackPorch;
            ++pixel_y;
        }

        if (pixel_x >= 0 && pixel_x < kVisibleWidth &&
            pixel_y >= 0 && pixel_y < kVisibleHeight && capturing) {
            framebuffer[pixel_y * kVisibleWidth + pixel_x] =
                rgb444_to_argb(top.VGA_R, top.VGA_G, top.VGA_B);
        }

        if (hsync_start && pixel_y == kVisibleHeight) {
            ++frame_count;

            if (options.frame_skip > 0) {
                if (skip_counter >= options.frame_skip) {
                    skip_counter = 0;
                    capturing = true;
                } else {
                    ++skip_counter;
                    capturing = false;
                }
            }

            uint64_t now = SDL_GetTicks64();
            bool should_present = capturing &&
                                  (options.present_every_frame ||
                                   (now - last_present_ticks >= 15));

            if (should_present) {
                SDL_UpdateTexture(texture, nullptr, framebuffer.data(),
                                  kVisibleWidth * sizeof(uint32_t));
                SDL_RenderClear(renderer);
                SDL_RenderCopy(renderer, texture, nullptr, nullptr);
                SDL_RenderPresent(renderer);
                last_present_ticks = SDL_GetTicks64();
            }

            if ((frame_count % 30) == 0) {
                char title[256];
                std::snprintf(title, sizeof(title),
                              "Nexys Game Console Verilator | frame=%d LED=%04x SW=%04x",
                              frame_count, static_cast<unsigned>(top.LED),
                              static_cast<unsigned>(switches));
                SDL_SetWindowTitle(window, title);
            }

            running = poll_events(top, ps2, switches);

            if (options.throttle && should_present) {
                uint64_t after_present = SDL_GetTicks64();
                uint64_t elapsed = after_present - now;
                if (elapsed < 1) {
                    SDL_Delay(1);
                }
            }

            if (options.max_frames >= 0 && frame_count >= options.max_frames) {
                running = false;
            }
        }

        ++pixel_x;
        prev_hs = hs;
        prev_vs = vs;

        if ((cycles & 0x03ff) == 0) {
            running = running && poll_events(top, ps2, switches);
        }
    }

    top.final();
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
