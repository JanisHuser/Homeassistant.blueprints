/* Unit literals: voltages in millivolts (4150_mV, 5_V), frequencies in hertz (10_MHz).
   Durations are std::chrono (2ms, 10s, 15min). */
#pragma once

#include <chrono>
#include <cstdint>

using namespace std::chrono_literals;

constexpr int operator""_mV(unsigned long long mv)
{
    return static_cast<int>(mv);
}

constexpr int operator""_V(unsigned long long v)
{
    return static_cast<int>(v * 1000);
}

constexpr uint32_t operator""_MHz(unsigned long long mhz)
{
    return static_cast<uint32_t>(mhz * 1000 * 1000);
}

/** A duration in microseconds, as esp_timer takes it. */
template <class Rep, class Period>
constexpr uint64_t to_us(std::chrono::duration<Rep, Period> d)
{
    return std::chrono::duration_cast<std::chrono::microseconds>(d).count();
}

/** A duration in milliseconds, as the button component takes it. */
template <class Rep, class Period>
constexpr uint32_t to_ms(std::chrono::duration<Rep, Period> d)
{
    return static_cast<uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(d).count());
}
