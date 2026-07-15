#include <windows.h>
#include <bcrypt.h>
#include <iostream>

#pragma comment(lib, "bcrypt.lib")

static constexpr const wchar_t* kProviderName = L"Remote A3 Key Storage Provider";
static constexpr const wchar_t* kDllName = L"RemoteA3Ksp.dll";

static void PrintStatus(const wchar_t* operation, NTSTATUS status)
{
    if (status == 0) {
        std::wcout << operation << L": OK" << std::endl;
        return;
    }

    std::wcout << operation << L": 0x" << std::hex << status << std::dec << std::endl;
}

static int RegisterProvider()
{
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
    userModeImage.pszImage = const_cast<PWSTR>(kDllName);
    userModeImage.cInterfaces = ARRAYSIZE(interfaces);
    userModeImage.rgpInterfaces = interfaces;

    CRYPT_PROVIDER_REG providerReg{};
    providerReg.cAliases = 0;
    providerReg.rgpszAliases = nullptr;
    providerReg.pUM = &userModeImage;
    providerReg.pKM = nullptr;

    NTSTATUS status = BCryptRegisterProvider(kProviderName, 0, &providerReg);
    PrintStatus(L"BCryptRegisterProvider", status);
    if (status != 0 && status != static_cast<NTSTATUS>(0xC0000035L)) {
        return 1;
    }

    for (auto* functionName : functions) {
        status = BCryptAddContextFunctionProvider(
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
    PWSTR functions[] = {
        const_cast<PWSTR>(BCRYPT_RSA_ALGORITHM),
        const_cast<PWSTR>(BCRYPT_RSA_SIGN_ALGORITHM),
    };

    for (auto* functionName : functions) {
        NTSTATUS status = BCryptRemoveContextFunctionProvider(
            CRYPT_LOCAL,
            nullptr,
            NCRYPT_INTERFACE,
            functionName,
            kProviderName);
        PrintStatus(functionName, status);
    }

    NTSTATUS status = BCryptUnregisterProvider(kProviderName);
    PrintStatus(L"BCryptUnregisterProvider", status);
    return status == 0 ? 0 : 1;
}

int wmain(int argc, wchar_t** argv)
{
    if (argc < 2) {
        std::wcerr << L"Usage: RemoteA3KspAdmin.exe register|unregister" << std::endl;
        return 2;
    }

    if (_wcsicmp(argv[1], L"register") == 0) {
        return RegisterProvider();
    }

    if (_wcsicmp(argv[1], L"unregister") == 0) {
        return UnregisterProvider();
    }

    std::wcerr << L"Unknown command: " << argv[1] << std::endl;
    return 2;
}

