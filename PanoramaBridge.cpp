// Panorama archive substitution for offline legacy 32-bit CS:GO.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include "minhook/include/MinHook.h"

static_assert(sizeof(void *) == 4, "Legacy CS:GO requires a 32-bit build");

using LoadZip = void(__fastcall *)(void *, void *, void *, unsigned int);
static LoadZip original_load_zip = nullptr;
static HMODULE self_module = nullptr;
static std::wstring base_dir;

static void log_message(const char *message)
{
    if (base_dir.empty()) return;
    FILE *file = nullptr;
    const std::wstring path = base_dir + L"PanoramaBridge.log";
    if (_wfopen_s(&file, path.c_str(), L"ab") == 0 && file) {
        std::fputs(message, file);
        std::fputs("\r\n", file);
        std::fclose(file);
    }
}

static bool read_archive(std::vector<unsigned char> &out)
{
    FILE *file = nullptr;
    const std::wstring path = base_dir + L"panorama.my.zip";
    if (_wfopen_s(&file, path.c_str(), L"rb") != 0 || !file) return false;
    bool ok = false;
    if (std::fseek(file, 0, SEEK_END) == 0) {
        const long length = std::ftell(file);
        if (length > 0 && length <= 64 * 1024 * 1024 &&
            std::fseek(file, 0, SEEK_SET) == 0) {
            out.resize(static_cast<size_t>(length));
            ok = std::fread(out.data(), 1, out.size(), file) == out.size();
        }
    }
    std::fclose(file);
    return ok;
}

static void capture_original_archive(void *data, unsigned int size)
{
    if (!data || size < 1024 * 1024 || size > 64 * 1024 * 1024 ||
        std::memcmp(data, "PK\x03\x04", 4) != 0) return;
    auto *bytes = static_cast<unsigned char *>(data);
    if (std::memcmp(bytes + 30, "panorama", 8) != 0 ||
        (bytes[38] != '/' && bytes[38] != '\\')) return;
    const std::wstring path = base_dir + L"panorama.org.zip";
    if (GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) return;
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    const bool ok = WriteFile(file, data, size, &written, nullptr) && written == size;
    CloseHandle(file);
    if (ok) log_message("Captured original Panorama ZIP locally");
    else {
        DeleteFileW(path.c_str());
        log_message("Could not capture original Panorama ZIP");
    }
}

static void __fastcall replacement_load_zip(
    void *instance, void *edx, void *original_data, unsigned int original_size)
{
    capture_original_archive(original_data, original_size);
    // Substitute only when the flag is present.
    const std::wstring flag_path = base_dir + L"enable-replacement.flag";
    if (GetFileAttributesW(flag_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
        log_message("CZip called in pass-through mode");
        original_load_zip(instance, edx, original_data, original_size);
        log_message("CZip pass-through returned");
        return;
    }
    std::vector<unsigned char> replacement;
    if (read_archive(replacement)) {
        log_message("Panorama ZIP request redirected to panorama.my.zip");
        original_load_zip(instance, edx, replacement.data(),
                          static_cast<unsigned int>(replacement.size()));
        log_message("Panorama ZIP redirect returned");
    } else {
        log_message("Replacement ZIP unavailable; using original bytes");
        original_load_zip(instance, edx, original_data, original_size);
        log_message("Fallback ZIP load returned");
    }
}

struct Section { unsigned char *start; size_t size; };

static bool image_sections(HMODULE module, Section &read_only,
                           Section &type_data, Section &code)
{
    auto *base = reinterpret_cast<unsigned char *>(module);
    auto *dos = reinterpret_cast<IMAGE_DOS_HEADER *>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
    auto *nt = reinterpret_cast<IMAGE_NT_HEADERS *>(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return false;
    auto *section = IMAGE_FIRST_SECTION(nt);
    for (unsigned int i = 0; i < nt->FileHeader.NumberOfSections; ++i) {
        const Section current{base + section[i].VirtualAddress,
                              section[i].Misc.VirtualSize};
        if (std::memcmp(section[i].Name, ".rdata", 6) == 0) read_only = current;
        if (std::memcmp(section[i].Name, ".data", 5) == 0) type_data = current;
        if (std::memcmp(section[i].Name, ".text", 5) == 0) code = current;
    }
    return read_only.start && type_data.start && code.start;
}

static bool in_section(const Section &section, uintptr_t value)
{
    const auto begin = reinterpret_cast<uintptr_t>(section.start);
    return value >= begin && value - begin < section.size;
}

static void **find_czip_vtable(HMODULE module)
{
    Section data{}, type_data{}, code{};
    if (!image_sections(module, data, type_data, code)) return nullptr;
    constexpr char name[] = ".?AVCZip@@";
    for (size_t i = 8; i + sizeof(name) <= type_data.size; ++i) {
        if (std::memcmp(type_data.start + i, name, sizeof(name)) != 0) continue;
        const auto descriptor = reinterpret_cast<uintptr_t>(type_data.start + i - 8);
        for (size_t j = 12; j + 8 < data.size; j += 4) {
            auto *candidate = reinterpret_cast<uint32_t *>(data.start + j);
            if (*candidate != descriptor) continue;
            auto *locator = candidate - 3; // x86 RTTI COL: sig, offset, cdOffset, type
            if (locator[0] != 0 || locator[1] != 0) continue;
            const auto locator_address = reinterpret_cast<uintptr_t>(locator);
            for (size_t k = 0; k + 4 + 15 * sizeof(void *) <= data.size; k += 4) {
                auto *pointer = reinterpret_cast<uint32_t *>(data.start + k);
                if (*pointer != locator_address) continue;
                auto **vtable = reinterpret_cast<void **>(pointer + 1);
                if (in_section(code, reinterpret_cast<uintptr_t>(vtable[0])) &&
                    in_section(code, reinterpret_cast<uintptr_t>(vtable[14])))
                    return vtable;
            }
        }
    }
    return nullptr;
}

static DWORD WINAPI initialize(void *)
{
    wchar_t module_path[MAX_PATH]{};
    if (!GetModuleFileNameW(self_module, module_path, MAX_PATH)) return 1;
    base_dir = module_path;
    const size_t separator = base_dir.find_last_of(L"\\/");
    if (separator == std::wstring::npos) return 1;
    base_dir.resize(separator + 1);
    log_message("PanoramaBridge started; waiting for panorama.dll");

    HMODULE panorama = nullptr;
    for (unsigned int i = 0; i < 30000 && !panorama; ++i) {
        panorama = GetModuleHandleW(L"panorama.dll");
        if (!panorama) Sleep(1);
    }
    if (!panorama) {
        log_message("panorama.dll not found within 30 seconds");
        return 2;
    }
    void **vtable = find_czip_vtable(panorama);
    if (!vtable) {
        log_message("CZip vtable not found; no hook installed");
        return 3;
    }
    if (MH_Initialize() != MH_OK) {
        log_message("MinHook initialization failed");
        return 4;
    }
    if (MH_CreateHook(vtable[14], reinterpret_cast<void *>(replacement_load_zip),
                      reinterpret_cast<void **>(&original_load_zip)) != MH_OK ||
        MH_EnableHook(vtable[14]) != MH_OK) {
        log_message("CZip function hook installation failed");
        return 5;
    }
    log_message("CZip archive-load function hooked");
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        self_module = module;
        DisableThreadLibraryCalls(module);
        HANDLE thread = CreateThread(nullptr, 0, initialize, nullptr, 0, nullptr);
        if (thread) CloseHandle(thread);
    }
    return TRUE;
}
