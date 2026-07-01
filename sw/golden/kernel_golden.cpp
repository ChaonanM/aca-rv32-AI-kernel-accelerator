#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>

int main() {
    constexpr std::array<std::uint32_t, 4> vector_a{1, 2, 3, 4};
    constexpr std::array<std::uint32_t, 4> vector_b{5, 6, 7, 8};
    
    std::uint32_t dot = 0;
    for (std::size_t index = 0; index < vector_a.size(); ++index) {
        const std::int64_t product = static_cast<std::int64_t>(vector_a[index]) * static_cast<std::int64_t>(vector_b[index]);
        dot += static_cast<std::uint32_t>(product);
    }

    constexpr std::size_t kDimension = 4;
    constexpr std::array<std::int32_t, 16> matrix_a{1, -2, 3, 4, 5, 6, -7, 8, -9, 10, 11, -12, 13, 14, 15, 16};
    constexpr std::array<std::int32_t, 16> matrix_b{2, 3, -4, 5, 6, -7, 8, 9, 10, 11, 12, -13, -14, 15, 16, 17};
    std::array<std::uint32_t, 16> gemm{};
    for (std::size_t row = 0; row < kDimension; ++row) {
        for (std::size_t col = 0; col < kDimension; ++col) {
            for (std::size_t inner = 0; inner < kDimension; ++inner) {
                const std::int64_t product = static_cast<std::int64_t>(matrix_a[(row * kDimension) + inner]) * static_cast<std::int64_t>(matrix_b[(inner * kDimension) + col]);
                gemm[(row * kDimension) + col] += static_cast<std::uint32_t>(product);
            }
        }
    }

    std::cout << dot;
    for (const std::uint32_t value : gemm) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
    return 0;
}