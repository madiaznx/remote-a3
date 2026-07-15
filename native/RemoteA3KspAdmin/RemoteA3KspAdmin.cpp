#include <windows.h>
#include <bcrypt.h>
#include <iostream>

#pragma comment(lib, "bcrypt.lib")

#ifndef NCRYPT_INTERFACE
#define NCRYPT_INTERFACE 0x00010001
#endif

typedef NTSTATUS(NTAPI* BCryptRegisterProviderPtr)(LPCWSTR, ULONG, PCRYPT_PROVIDER_REG);
typedef NTSTATUS(NTAPI* BCryptUnregisterProviderPtr)(LPCWSTR);
typedef NTSTATUS(NTAPI* BCryptAddContextFunctionProviderPtr)(ULONG, LPCWSTR, ULONG, LPCWSTR, LPCWSTR, ULONG);
typedef NTSTATUS(NTAPI* BCryptRemoveContextFunctionProviderPtr)(ULONG, LPCWSTR, ULONG, LPCWSTR, LPCWSTR);

struct BCryptApi {
    HMODULE module = nullptr;
    BCryptRegisterProviderPtr RegisterProvider = nullptr;
    BCryptUnregisterProviderPtr UnregisterProvider = nullptr;
    BCryptAddContextFunctionProviderPtr AddContextFunctionProvider = nullptr;
    BCryptRemoveContextFunctionProviderPtr RemoveContextFunctionProvider = nullptr;

    ~BCryptApi()
    {
        if (module) {
            FreeLibrary(module);
        }
    }

    bool Load()
    {
        module = LoadLibraryW(L"bcrypt.dll");
        if (!module) {
            return false;
        }

        RegisterProvider = reinterpret_cast<BCryptRegisterProviderPtr>(GetProcAddress(module, "BCryptRegisterProvider"));
        UnregisterProvider = reinterpret_cast<BCryptUnregisterProviderPtr>(GetProcAddress(module, "BCryptUnregisterProvider"));
        AddContextFunctionProvider = reinterpret_cast<BCryptAddContextFunctionProviderPtr>(GetProcAddress(module, "BCryptAddContextFunctionProvider"));
        RemoveContextFunctionProvider = reinterpret_cast<BCryptRemoveContextFunctionProviderPtr>(GetProcAddress(module, "BCryptRemoveContextFunctionProvider"));

        return RegisterProvider && UnregisterProvider && AddContextFunctionProvider && RemoveContextFunctionProvider;
    }
};

static constexpr const wchar_t* kProviderName = L"Remote A3 Key Storage Provider";
static constexpr const wchar_t* kDllName = L"RemoteA3Ksp.dll";

static std::wstring GetExecutableDirectory()
{
    wchar_t path[MAX_PATH]{};
    DWORD chars = GetModuleFileNameW(nullptr, path, ARRAYSIZE(path));
    if (chars == 0 || chars >= ARRAYSIZE(path)) {
        return L".";
    }

    std::wstring value(path);
    size_t slash = value.find_last_of(L"\\/");
    if (slash == std::wstring::npos) {
        return L".";
    }

    return value.substr(0, slash);
}

static std::wstring GetDefaultDllPath()
{
    return GetExecutableDirectory() + L"\\" + kDllName;
}

static void PrintStatus(const wchar_t* operation, NTSTATUS status)
{
    if (status == 0) {
        std::wcout << operation << L": OK" << std::endl;
        return;
    }

    std::wcout << operation << L": 0x" << std::hex << status << std::dec << std::endl;
}

static int RegisterProvider(const std::wstring& dllPath)
{
    BCryptApi api;
    if (!api.Load()) {
        std::wcerr << L"Falha ao carregar APIs de registro CNG em bcrypt.dll" << std::endl;
        return 1;
    }

    PWSTR functions[] = {
        const_cast<PWSTR>(BCRYPT_RSA_ALGORITHM),
        const_cast<PWSTR>(BCRYPT_RSA_SIGN_ALGORITHM),
    };

    CRYPT_INTERFACE_REG interfaceReg{};
    interfaceReg.dwInterface = NCRYPT_INTERFACE;
    interfaceReg.dwFlags = 0;
    interfaceReg.cFunctions = ARRAYSIZE(functions);
    interfaceReg.rgpszFunctions = functions;

    PCRYPT_INTERFACE_REG interfaces[] = { &interfaceReg };

    CRYPT_IMAGE_REG userModeImage{};
    userModeImage.pszImage = const_cast<PWSTR>(dllPath.c_str());
    userModeImage.cInterfaces = ARRAYSIZE(interfaces);
    userModeImage.rgpInterfaces = interfaces;

    CRYPT_PROVIDER_REG providerReg{};
    providerReg.cAliases = 0;
    providerReg.rgpszAliases = nullptr;
    providerReg.pUM = &userModeImage;
    providerReg.pKM = nullptr;

    NTSTATUS status = api.RegisterProvider(kProviderName, 0, &providerReg);
    PrintStatus(L"BCryptRegisterProvider", status);
    if (status != 0 && status != static_cast<NTSTATUS>(0xC0000035L)) {
        return 1;
    }

    for (auto* functionName : functions) {
        status = api.AddContextFunctionProvider(
            CRYPT_LOCAL,
            nullptr,
            NCRYPT_INTERFACE,
            functionName,
            kProviderName,
            CRYPT_PRIORITY_TOP);
        PrintStatus(functionName, status);
        if (status != 0 && status != static_cast<NTSTATUS>(0xC0000035L)) {
            return 1;
        }
    }

    return 0;
}

static int UnregisterProvider()
{
    BCryptApi api;
    if (!api.Load()) {
        std::wcerr << L"Falha ao carregar APIs de registro CNG em bcrypt.dll" << std::endl;
        return 1;
    }

    PWSTR functions[] = {
        const_cast<PWSTR>(BCRYPT_RSA_ALGORITHM),
        const_cast<PWSTR>(BCRYPT_RSA_SIGN_ALGORITHM),
    };

    for (auto* functionName : functions) {
        NTSTATUS status = api.RemoveContextFunctionProvider(
            CRYPT_LOCAL,
            nullptr,
            NCRYPT_INTERFACE,
            functionName,
            kProviderName);
        PrintStatus(functionName, status);
    }

    NTSTATUS status = api.UnregisterProvider(kProviderName);
    PrintStatus(L"BCryptUnregisterProvider", status);
    return status == 0 ? 0 : 1;
}

int wmain(int argc, wchar_t** argv)
{
    if (argc < 2) {
        std::wcerr << L"Usage: RemoteA3KspAdmin.exe register [RemoteA3Ksp.dll path]|unregister" << std::endl;
        return 2;
    }

    if (_wcsicmp(argv[1], L"register") == 0) {
        std::wstring dllPath = argc >= 3 ? argv[2] : GetDefaultDllPath();
        std::wcout << L"DLL: " << dllPath << std::endl;
        return RegisterProvider(dllPath);
    }

    if (_wcsicmp(argv[1], L"unregister") == 0) {
        return UnregisterProvider();
    }

    std::wcerr << L"Unknown command: " << argv[1] << std::endl;
    return 2;
}
