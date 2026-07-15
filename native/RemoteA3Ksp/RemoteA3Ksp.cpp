#include <windows.h>
#include <bcrypt.h>
#include <ncrypt.h>
#include <wincrypt.h>
#include <wincred.h>
#include <winhttp.h>

#if __has_include(<ncrypt_provider.h>)
#include <ncrypt_provider.h>
#else
typedef HRESULT(WINAPI* NCryptOpenStorageProviderFn)(NCRYPT_PROV_HANDLE*, LPCWSTR, DWORD);
typedef HRESULT(WINAPI* NCryptOpenKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE*, LPCWSTR, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptCreatePersistedKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE*, LPCWSTR, LPCWSTR, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptGetProviderPropertyFn)(NCRYPT_PROV_HANDLE, LPCWSTR, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptGetKeyPropertyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, LPCWSTR, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptSetProviderPropertyFn)(NCRYPT_PROV_HANDLE, LPCWSTR, PBYTE, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptSetKeyPropertyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, LPCWSTR, PBYTE, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptFinalizeKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, DWORD);
typedef HRESULT(WINAPI* NCryptDeleteKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, DWORD);
typedef HRESULT(WINAPI* NCryptFreeProviderFn)(NCRYPT_PROV_HANDLE);
typedef HRESULT(WINAPI* NCryptFreeKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE);
typedef HRESULT(WINAPI* NCryptFreeBufferFn)(PVOID);
typedef HRESULT(WINAPI* NCryptEncryptFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, PBYTE, DWORD, VOID*, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptDecryptFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, PBYTE, DWORD, VOID*, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptIsAlgSupportedFn)(NCRYPT_PROV_HANDLE, LPCWSTR, DWORD);
typedef HRESULT(WINAPI* NCryptEnumAlgorithmsFn)(NCRYPT_PROV_HANDLE, DWORD, DWORD*, BCRYPT_ALGORITHM_IDENTIFIER**, DWORD);
typedef HRESULT(WINAPI* NCryptEnumKeysFn)(NCRYPT_PROV_HANDLE, LPCWSTR, NCryptKeyName**, PVOID*, DWORD);
typedef HRESULT(WINAPI* NCryptImportKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, LPCWSTR, NCryptBufferDesc*, NCRYPT_KEY_HANDLE*, PBYTE, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptExportKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, NCRYPT_KEY_HANDLE, LPCWSTR, NCryptBufferDesc*, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptSignHashFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, VOID*, PBYTE, DWORD, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptVerifySignatureFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, VOID*, PBYTE, DWORD, PBYTE, DWORD, DWORD);
typedef HRESULT(WINAPI* NCryptPromptUserFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, LPCWSTR, DWORD);
typedef HRESULT(WINAPI* NCryptNotifyChangeKeyFn)(NCRYPT_PROV_HANDLE, HANDLE*, DWORD);
typedef HRESULT(WINAPI* NCryptSecretAgreementFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, NCRYPT_KEY_HANDLE, NCRYPT_SECRET_HANDLE*, DWORD);
typedef HRESULT(WINAPI* NCryptDeriveKeyFn)(NCRYPT_PROV_HANDLE, NCRYPT_SECRET_HANDLE, LPCWSTR, NCryptBufferDesc*, PBYTE, DWORD, DWORD*, ULONG);
typedef HRESULT(WINAPI* NCryptFreeSecretFn)(NCRYPT_PROV_HANDLE, NCRYPT_SECRET_HANDLE);
typedef HRESULT(WINAPI* NCryptKeyDerivationFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, NCryptBufferDesc*, PBYTE, DWORD, DWORD*, ULONG);
typedef HRESULT(WINAPI* NCryptCreateClaimFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, NCRYPT_KEY_HANDLE, DWORD, NCryptBufferDesc*, PBYTE, DWORD, DWORD*, DWORD);
typedef HRESULT(WINAPI* NCryptVerifyClaimFn)(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE, NCRYPT_KEY_HANDLE, DWORD, NCryptBufferDesc*, PBYTE, DWORD, DWORD);

typedef struct _NCRYPT_KEY_STORAGE_FUNCTION_TABLE {
    BCRYPT_INTERFACE_VERSION Version;
    NCryptOpenStorageProviderFn OpenProvider;
    NCryptOpenKeyFn OpenKey;
    NCryptCreatePersistedKeyFn CreatePersistedKey;
    NCryptGetProviderPropertyFn GetProviderProperty;
    NCryptGetKeyPropertyFn GetKeyProperty;
    NCryptSetProviderPropertyFn SetProviderProperty;
    NCryptSetKeyPropertyFn SetKeyProperty;
    NCryptFinalizeKeyFn FinalizeKey;
    NCryptDeleteKeyFn DeleteKey;
    NCryptFreeProviderFn FreeProvider;
    NCryptFreeKeyFn FreeKey;
    NCryptFreeBufferFn FreeBuffer;
    NCryptEncryptFn Encrypt;
    NCryptDecryptFn Decrypt;
    NCryptIsAlgSupportedFn IsAlgSupported;
    NCryptEnumAlgorithmsFn EnumAlgorithms;
    NCryptEnumKeysFn EnumKeys;
    NCryptImportKeyFn ImportKey;
    NCryptExportKeyFn ExportKey;
    NCryptSignHashFn SignHash;
    NCryptVerifySignatureFn VerifySignature;
    NCryptPromptUserFn PromptUser;
    NCryptNotifyChangeKeyFn NotifyChangeKey;
    NCryptSecretAgreementFn SecretAgreement;
    NCryptDeriveKeyFn DeriveKey;
    NCryptFreeSecretFn FreeSecret;
    NCryptKeyDerivationFn KeyDerivation;
    NCryptCreateClaimFn CreateClaim;
    NCryptVerifyClaimFn VerifyClaim;
} NCRYPT_KEY_STORAGE_FUNCTION_TABLE;
#endif

#include <algorithm>
#include <ctime>
#include <fstream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "advapi32.lib")

#ifndef CREDUI_MAX_USERNAME_LENGTH
#define CREDUI_MAX_USERNAME_LENGTH 513
#endif

#ifndef CREDUI_MAX_PASSWORD_LENGTH
#define CREDUI_MAX_PASSWORD_LENGTH 256
#endif

#ifndef CREDUI_FLAGS_DO_NOT_PERSIST
#define CREDUI_FLAGS_DO_NOT_PERSIST 0x00000002
#endif

#ifndef CREDUI_FLAGS_KEEP_USERNAME
#define CREDUI_FLAGS_KEEP_USERNAME 0x00100000
#endif

#ifndef CREDUI_FLAGS_EXCLUDE_CERTIFICATES
#define CREDUI_FLAGS_EXCLUDE_CERTIFICATES 0x00000008
#endif

#ifndef CREDUI_FLAGS_PASSWORD_ONLY_OK
#define CREDUI_FLAGS_PASSWORD_ONLY_OK 0x00000200
#endif

#ifndef CREDUI_FLAGS_ALWAYS_SHOW_UI
#define CREDUI_FLAGS_ALWAYS_SHOW_UI 0x00000080
#endif

#ifndef CREDUI_FLAGS_GENERIC_CREDENTIALS
#define CREDUI_FLAGS_GENERIC_CREDENTIALS 0x00040000
#endif

typedef struct _RA3_CREDUI_INFOW {
    DWORD cbSize;
    HWND hwndParent;
    PCWSTR pszMessageText;
    PCWSTR pszCaptionText;
    HBITMAP hbmBanner;
} RA3_CREDUI_INFOW;

typedef DWORD(WINAPI* RA3_CredUIPromptForCredentialsW)(
    RA3_CREDUI_INFOW* pUiInfo,
    PCWSTR pszTargetName,
    const void* Reserved,
    DWORD dwAuthError,
    PWSTR pszUserName,
    ULONG ulUserNameMaxChars,
    PWSTR pszPassword,
    ULONG ulPasswordMaxChars,
    BOOL* save,
    DWORD dwFlags);

static constexpr DWORD kProviderMagic = 0x33415250; // PRA3
static constexpr DWORD kKeyMagic = 0x33414B52;      // RKA3
static constexpr const wchar_t* kProviderName = L"Remote A3 Key Storage Provider";

struct ProviderContext {
    DWORD magic = kProviderMagic;
};

struct KeyContext {
    DWORD magic = kKeyMagic;
    ProviderContext* provider = nullptr;
    std::wstring containerName;
    std::wstring agentUrl;
    std::wstring thumbprint;
    std::wstring scope = L"Both";
    std::wstring storeName = L"My";
    std::wstring publicCertificateBase64;
    std::wstring credentialTarget;
    std::wstring networkUser;
    std::wstring networkPassword;
    std::wstring cachedPin;
    DWORD keyLength = 2048;
};

static ProviderContext* AsProvider(NCRYPT_PROV_HANDLE hProvider)
{
    auto* ctx = reinterpret_cast<ProviderContext*>(hProvider);
    return (ctx && ctx->magic == kProviderMagic) ? ctx : nullptr;
}

static KeyContext* AsKey(NCRYPT_KEY_HANDLE hKey)
{
    auto* ctx = reinterpret_cast<KeyContext*>(hKey);
    return (ctx && ctx->magic == kKeyMagic) ? ctx : nullptr;
}

static std::wstring Trim(std::wstring value)
{
    auto isSpace = [](wchar_t c) { return c == L' ' || c == L'\t' || c == L'\r' || c == L'\n'; };
    value.erase(value.begin(), std::find_if(value.begin(), value.end(), [&](wchar_t c) { return !isSpace(c); }));
    value.erase(std::find_if(value.rbegin(), value.rend(), [&](wchar_t c) { return !isSpace(c); }).base(), value.end());
    return value;
}

static bool WriteOutput(const void* data, DWORD size, PBYTE output, DWORD outputSize, DWORD* result)
{
    if (result) {
        *result = size;
    }

    if (!output) {
        return true;
    }

    if (outputSize < size) {
        return false;
    }

    CopyMemory(output, data, size);
    return true;
}

static HRESULT WriteDword(DWORD value, PBYTE output, DWORD outputSize, DWORD* result)
{
    return WriteOutput(&value, sizeof(value), output, outputSize, result) ? S_OK : HRESULT_FROM_WIN32(ERROR_MORE_DATA);
}

static HRESULT WriteHandle(ULONG_PTR value, PBYTE output, DWORD outputSize, DWORD* result)
{
    return WriteOutput(&value, sizeof(value), output, outputSize, result) ? S_OK : HRESULT_FROM_WIN32(ERROR_MORE_DATA);
}

static HRESULT WriteWideString(const std::wstring& value, PBYTE output, DWORD outputSize, DWORD* result)
{
    const DWORD bytes = static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
    return WriteOutput(value.c_str(), bytes, output, outputSize, result) ? S_OK : HRESULT_FROM_WIN32(ERROR_MORE_DATA);
}

static HRESULT DecodeBase64(const std::wstring& input, std::vector<BYTE>& output)
{
    DWORD size = 0;
    if (!CryptStringToBinaryW(input.c_str(), 0, CRYPT_STRING_BASE64, nullptr, &size, nullptr, nullptr)) {
        return HRESULT_FROM_WIN32(GetLastError());
    }

    output.resize(size);
    if (!CryptStringToBinaryW(input.c_str(), 0, CRYPT_STRING_BASE64, output.data(), &size, nullptr, nullptr)) {
        return HRESULT_FROM_WIN32(GetLastError());
    }

    output.resize(size);
    return S_OK;
}

static std::wstring EncodeBase64(const BYTE* data, DWORD size)
{
    DWORD chars = 0;
    CryptBinaryToStringW(data, size, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, nullptr, &chars);
    std::wstring result(chars, L'\0');
    if (!CryptBinaryToStringW(data, size, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, result.data(), &chars)) {
        return L"";
    }
    if (!result.empty() && result.back() == L'\0') {
        result.pop_back();
    }
    return result;
}

static std::string WideToUtf8(const std::wstring& value)
{
    if (value.empty()) {
        return {};
    }

    int needed = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string result(static_cast<size_t>(needed > 0 ? needed - 1 : 0), '\0');
    if (needed > 1) {
        WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), needed, nullptr, nullptr);
    }
    return result;
}

static std::wstring GetLocalAppDataPath()
{
    wchar_t buffer[MAX_PATH]{};
    DWORD chars = GetEnvironmentVariableW(L"LOCALAPPDATA", buffer, ARRAYSIZE(buffer));
    if (chars == 0 || chars >= ARRAYSIZE(buffer)) {
        return L"";
    }
    return buffer;
}

static void EnsureDirectory(const std::wstring& path)
{
    if (path.empty()) {
        return;
    }
    CreateDirectoryW(path.c_str(), nullptr);
}

static std::wstring LogPath()
{
    std::wstring base = GetLocalAppDataPath();
    if (base.empty()) {
        return L"";
    }

    std::wstring appDir = base + L"\\RemoteA3";
    std::wstring logDir = appDir + L"\\logs";
    EnsureDirectory(appDir);
    EnsureDirectory(logDir);
    return logDir + L"\\ksp.log";
}

static void LogLine(const std::wstring& message)
{
    std::wstring path = LogPath();
    if (path.empty()) {
        return;
    }

    SYSTEMTIME now{};
    GetLocalTime(&now);
    wchar_t timestamp[64]{};
    swprintf_s(
        timestamp,
        L"%04u-%02u-%02u %02u:%02u:%02u.%03u",
        now.wYear,
        now.wMonth,
        now.wDay,
        now.wHour,
        now.wMinute,
        now.wSecond,
        now.wMilliseconds);

    std::wofstream file(path, std::ios::app);
    if (file.good()) {
        file << timestamp << L" " << message << std::endl;
    }
}

static std::wstring KeyConfigPath(const std::wstring& containerName)
{
    std::wstring base = GetLocalAppDataPath();
    if (base.empty()) {
        return L"";
    }
    return base + L"\\RemoteA3\\keys\\" + containerName + L".remotea3";
}

static bool ReadStoredCredential(const std::wstring& targetName, std::wstring& username, std::wstring& password)
{
    if (targetName.empty()) {
        LogLine(L"Credential target empty.");
        return false;
    }

    PCREDENTIALW credential = nullptr;
    if (!CredReadW(targetName.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
        LogLine(L"CredRead failed for target " + targetName + L" error=" + std::to_wstring(GetLastError()));
        return false;
    }

    if (credential->UserName) {
        username = credential->UserName;
    }

    if (credential->CredentialBlob && credential->CredentialBlobSize > 0) {
        password.assign(
            reinterpret_cast<const wchar_t*>(credential->CredentialBlob),
            credential->CredentialBlobSize / sizeof(wchar_t));
        if (!password.empty() && password.back() == L'\0') {
            password.pop_back();
        }
    }

    CredFree(credential);
    LogLine(L"Credential loaded for target " + targetName + L" user=" + username + L" hasPassword=" + (password.empty() ? L"false" : L"true"));
    return !username.empty();
}

static bool LoadKeyConfig(const std::wstring& containerName, KeyContext& key)
{
    std::wstring path = KeyConfigPath(containerName);
    if (path.empty()) {
        return false;
    }

    std::wifstream file(path);
    if (!file.good()) {
        return false;
    }

    std::wstring line;
    while (std::getline(file, line)) {
        size_t pos = line.find(L'=');
        if (pos == std::wstring::npos) {
            continue;
        }

        std::wstring name = Trim(line.substr(0, pos));
        std::wstring value = Trim(line.substr(pos + 1));
        if (_wcsicmp(name.c_str(), L"agentUrl") == 0) key.agentUrl = value;
        else if (_wcsicmp(name.c_str(), L"thumbprint") == 0) key.thumbprint = value;
        else if (_wcsicmp(name.c_str(), L"scope") == 0) key.scope = value;
        else if (_wcsicmp(name.c_str(), L"storeName") == 0) key.storeName = value;
        else if (_wcsicmp(name.c_str(), L"publicCertificateBase64") == 0) key.publicCertificateBase64 = value;
        else if (_wcsicmp(name.c_str(), L"keyLength") == 0) key.keyLength = wcstoul(value.c_str(), nullptr, 10);
        else if (_wcsicmp(name.c_str(), L"credentialTarget") == 0) key.credentialTarget = value;
    }

    bool credentialLoaded = ReadStoredCredential(key.credentialTarget, key.networkUser, key.networkPassword);
    LogLine(
        L"LoadKeyConfig container=" + containerName +
        L" agentUrl=" + key.agentUrl +
        L" credentialTarget=" + key.credentialTarget +
        L" credentialLoaded=" + (credentialLoaded ? L"true" : L"false"));

    return !key.agentUrl.empty() && !key.thumbprint.empty();
}

static std::wstring JsonValue(const std::string& json, const std::string& name)
{
    std::string needle = "\"" + name + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) {
        return L"";
    }
    pos = json.find(':', pos + needle.size());
    if (pos == std::string::npos) {
        return L"";
    }
    ++pos;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')) {
        ++pos;
    }
    if (pos >= json.size() || json[pos] != '"') {
        return L"";
    }
    ++pos;
    std::string raw;
    while (pos < json.size() && json[pos] != '"') {
        raw.push_back(json[pos++]);
    }

    int needed = MultiByteToWideChar(CP_UTF8, 0, raw.c_str(), -1, nullptr, 0);
    std::wstring result(static_cast<size_t>(needed > 0 ? needed - 1 : 0), L'\0');
    if (needed > 1) {
        MultiByteToWideChar(CP_UTF8, 0, raw.c_str(), -1, result.data(), needed);
    }
    return result;
}

static std::wstring EscapeJson(const std::wstring& value)
{
    std::wstring out;
    for (wchar_t c : value) {
        if (c == L'\\' || c == L'"') {
            out.push_back(L'\\');
        }
        out.push_back(c);
    }
    return out;
}

static HRESULT PromptForPin(KeyContext& key, DWORD flags)
{
    if (!key.cachedPin.empty()) {
        return S_OK;
    }

    if (flags & NCRYPT_SILENT_FLAG) {
        return NTE_SILENT_CONTEXT;
    }

    HMODULE credui = LoadLibraryW(L"credui.dll");
    if (!credui) {
        return HRESULT_FROM_WIN32(GetLastError());
    }

    auto prompt = reinterpret_cast<RA3_CredUIPromptForCredentialsW>(
        GetProcAddress(credui, "CredUIPromptForCredentialsW"));
    if (!prompt) {
        DWORD error = GetLastError();
        FreeLibrary(credui);
        return HRESULT_FROM_WIN32(error);
    }

    RA3_CREDUI_INFOW info{};
    info.cbSize = sizeof(info);
    info.pszCaptionText = L"Remote A3";
    info.pszMessageText = L"Digite o PIN do certificado A3 remoto";

    wchar_t username[CREDUI_MAX_USERNAME_LENGTH + 1]{};
    wchar_t password[CREDUI_MAX_PASSWORD_LENGTH + 1]{};
    BOOL save = FALSE;

    wcsncpy_s(username, ARRAYSIZE(username), L"RemoteA3", _TRUNCATE);

    DWORD promptFlags =
        CREDUI_FLAGS_DO_NOT_PERSIST |
        CREDUI_FLAGS_EXCLUDE_CERTIFICATES |
        CREDUI_FLAGS_PASSWORD_ONLY_OK |
        CREDUI_FLAGS_GENERIC_CREDENTIALS |
        CREDUI_FLAGS_ALWAYS_SHOW_UI;

    DWORD result = prompt(
        &info,
        L"RemoteA3",
        nullptr,
        0,
        username,
        ARRAYSIZE(username),
        password,
        ARRAYSIZE(password),
        &save,
        promptFlags);

    if (result == ERROR_INVALID_FLAGS) {
        promptFlags =
            CREDUI_FLAGS_DO_NOT_PERSIST |
            CREDUI_FLAGS_EXCLUDE_CERTIFICATES |
            CREDUI_FLAGS_PASSWORD_ONLY_OK |
            CREDUI_FLAGS_GENERIC_CREDENTIALS;

        result = prompt(
            &info,
            L"RemoteA3",
            nullptr,
            0,
            username,
            ARRAYSIZE(username),
            password,
            ARRAYSIZE(password),
            &save,
            promptFlags);
    }

    if (result == ERROR_INVALID_FLAGS) {
        promptFlags =
            CREDUI_FLAGS_DO_NOT_PERSIST |
            CREDUI_FLAGS_EXCLUDE_CERTIFICATES |
            CREDUI_FLAGS_GENERIC_CREDENTIALS;

        result = prompt(
            &info,
            L"RemoteA3",
            nullptr,
            0,
            username,
            ARRAYSIZE(username),
            password,
            ARRAYSIZE(password),
            &save,
            promptFlags);
    }

    if (result != NO_ERROR) {
        SecureZeroMemory(password, sizeof(password));
        FreeLibrary(credui);
        return HRESULT_FROM_WIN32(result);
    }

    key.cachedPin = password;
    SecureZeroMemory(password, sizeof(password));
    FreeLibrary(credui);
    return S_OK;
}

static bool HasCredentialDomain(const std::wstring& username)
{
    return username.find(L'\\') != std::wstring::npos || username.find(L'@') != std::wstring::npos;
}

static std::vector<std::wstring> BuildCredentialUserCandidates(const std::wstring& username, const std::wstring& hostName)
{
    std::vector<std::wstring> users;
    if (username.empty()) {
        return users;
    }

    users.push_back(username);

    if (!HasCredentialDomain(username) && !hostName.empty()) {
        std::wstring hostUser = hostName + L"\\" + username;
        if (std::find(users.begin(), users.end(), hostUser) == users.end()) {
            users.push_back(hostUser);
        }
    }

    return users;
}

static HRESULT HttpPostJson(
    const std::wstring& url,
    const std::wstring& json,
    const std::wstring& networkUser,
    const std::wstring& networkPassword,
    std::string& response)
{
    URL_COMPONENTS parts{};
    parts.dwStructSize = sizeof(parts);
    wchar_t host[256]{};
    wchar_t path[2048]{};
    parts.lpszHostName = host;
    parts.dwHostNameLength = ARRAYSIZE(host);
    parts.lpszUrlPath = path;
    parts.dwUrlPathLength = ARRAYSIZE(path);

    if (!WinHttpCrackUrl(url.c_str(), 0, 0, &parts)) {
        LogLine(L"WinHttpCrackUrl failed error=" + std::to_wstring(GetLastError()));
        return HRESULT_FROM_WIN32(GetLastError());
    }

    HINTERNET session = WinHttpOpen(L"RemoteA3Ksp/0.3", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session) {
        LogLine(L"WinHttpOpen failed error=" + std::to_wstring(GetLastError()));
        return HRESULT_FROM_WIN32(GetLastError());
    }

    std::wstring hostName(host, parts.dwHostNameLength);
    HINTERNET connect = WinHttpConnect(session, hostName.c_str(), parts.nPort, 0);
    if (!connect) {
        DWORD error = GetLastError();
        LogLine(L"WinHttpConnect failed error=" + std::to_wstring(error));
        WinHttpCloseHandle(session);
        return HRESULT_FROM_WIN32(error);
    }

    DWORD requestFlags = parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0;
    std::wstring requestPath(path, parts.dwUrlPathLength);

    auto authSchemeName = [](DWORD scheme) -> std::wstring {
        switch (scheme) {
        case WINHTTP_AUTH_SCHEME_NEGOTIATE: return L"Negotiate";
        case WINHTTP_AUTH_SCHEME_NTLM: return L"NTLM";
        case WINHTTP_AUTH_SCHEME_BASIC: return L"Basic";
        case WINHTTP_AUTH_SCHEME_PASSPORT: return L"Passport";
        case WINHTTP_AUTH_SCHEME_DIGEST: return L"Digest";
        default: return L"0x" + std::to_wstring(scheme);
        }
    };

    auto chooseAuthScheme = [](DWORD supportedSchemes) -> DWORD {
        if (supportedSchemes & WINHTTP_AUTH_SCHEME_NEGOTIATE) return WINHTTP_AUTH_SCHEME_NEGOTIATE;
        if (supportedSchemes & WINHTTP_AUTH_SCHEME_NTLM) return WINHTTP_AUTH_SCHEME_NTLM;
        if (supportedSchemes & WINHTTP_AUTH_SCHEME_BASIC) return WINHTTP_AUTH_SCHEME_BASIC;
        if (supportedSchemes & WINHTTP_AUTH_SCHEME_DIGEST) return WINHTTP_AUTH_SCHEME_DIGEST;
        return 0;
    };

    std::string body = WideToUtf8(json);
    const wchar_t* headers = L"Content-Type: application/json; charset=utf-8\r\n";

    auto postOnce = [&](bool useStoredCredential, const std::wstring& credentialUser, DWORD authScheme, DWORD& statusCode, DWORD& supportedSchemes, std::string& bodyResponse) -> HRESULT {
        HINTERNET request = WinHttpOpenRequest(connect, L"POST", requestPath.c_str(), nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, requestFlags);
        if (!request) {
            DWORD error = GetLastError();
            LogLine(L"WinHttpOpenRequest failed error=" + std::to_wstring(error));
            return HRESULT_FROM_WIN32(error);
        }

        DWORD autoLogon = WINHTTP_AUTOLOGON_SECURITY_LEVEL_LOW;
        WinHttpSetOption(request, WINHTTP_OPTION_AUTOLOGON_POLICY, &autoLogon, sizeof(autoLogon));

        auto sendAndReceive = [&](bool withBody) -> HRESULT {
            BOOL ok = WinHttpSendRequest(
                request,
                headers,
                static_cast<DWORD>(-1L),
                (withBody && !body.empty()) ? body.data() : nullptr,
                withBody ? static_cast<DWORD>(body.size()) : 0,
                withBody ? static_cast<DWORD>(body.size()) : 0,
                0);

            if (ok) {
                ok = WinHttpReceiveResponse(request, nullptr);
            }

            if (!ok) {
                DWORD error = GetLastError();
                LogLine(L"WinHttpSend/Receive failed error=" + std::to_wstring(error) + L" useStoredCredential=" + (useStoredCredential ? L"true" : L"false"));
                return HRESULT_FROM_WIN32(error);
            }

            statusCode = 0;
            DWORD statusSize = sizeof(statusCode);
            WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, nullptr, &statusCode, &statusSize, nullptr);
            LogLine(L"HTTP status=" + std::to_wstring(statusCode) + L" useStoredCredential=" + (useStoredCredential ? L"true" : L"false"));

            supportedSchemes = 0;
            DWORD firstScheme = 0;
            DWORD authTarget = 0;
            if (statusCode == HTTP_STATUS_DENIED && WinHttpQueryAuthSchemes(request, &supportedSchemes, &firstScheme, &authTarget)) {
                LogLine(L"HTTP auth challenge schemes=" + std::to_wstring(supportedSchemes) + L" first=" + authSchemeName(firstScheme));
            }

            return S_OK;
        };

        HRESULT hr = sendAndReceive(true);
        if (FAILED(hr)) {
            WinHttpCloseHandle(request);
            return hr;
        }

        if (useStoredCredential) {
            DWORD credentialScheme = authScheme ? authScheme : chooseAuthScheme(supportedSchemes);
            if (!credentialScheme) {
                LogLine(L"No auth scheme available for stored credential.");
                WinHttpCloseHandle(request);
                return S_OK;
            }

            LogLine(L"WinHttpSetCredentials user=" + credentialUser + L" scheme=" + authSchemeName(credentialScheme));
            if (!WinHttpSetCredentials(
                    request,
                    WINHTTP_AUTH_TARGET_SERVER,
                    credentialScheme,
                    credentialUser.c_str(),
                    networkPassword.c_str(),
                    nullptr)) {
                DWORD error = GetLastError();
                LogLine(L"WinHttpSetCredentials failed error=" + std::to_wstring(error));
                WinHttpCloseHandle(request);
                return HRESULT_FROM_WIN32(error);
            }

            hr = sendAndReceive(true);
            if (FAILED(hr)) {
                WinHttpCloseHandle(request);
                return hr;
            }
        }

        bodyResponse.clear();
        if (statusCode >= 200 && statusCode <= 299) {
            DWORD available = 0;
            while (WinHttpQueryDataAvailable(request, &available) && available > 0) {
                std::string chunk(available, '\0');
                DWORD read = 0;
                if (!WinHttpReadData(request, chunk.data(), available, &read)) {
                    break;
                }
                chunk.resize(read);
                bodyResponse += chunk;
            }
        }

        WinHttpCloseHandle(request);
        return S_OK;
    };

    DWORD statusCode = 0;
    DWORD supportedSchemes = 0;
    HRESULT hr = postOnce(false, L"", 0, statusCode, supportedSchemes, response);
    if (FAILED(hr)) {
        WinHttpCloseHandle(connect);
        WinHttpCloseHandle(session);
        return hr;
    }

    if (statusCode == HTTP_STATUS_DENIED && !networkUser.empty()) {
        std::vector<std::wstring> userCandidates = BuildCredentialUserCandidates(networkUser, hostName);
        DWORD chosenScheme = chooseAuthScheme(supportedSchemes);
        DWORD schemes[4]{};
        DWORD schemeCount = 0;
        if (chosenScheme) {
            schemes[schemeCount++] = chosenScheme;
        }
        if (chosenScheme != WINHTTP_AUTH_SCHEME_NEGOTIATE) schemes[schemeCount++] = WINHTTP_AUTH_SCHEME_NEGOTIATE;
        if (chosenScheme != WINHTTP_AUTH_SCHEME_NTLM) schemes[schemeCount++] = WINHTTP_AUTH_SCHEME_NTLM;
        if (chosenScheme != WINHTTP_AUTH_SCHEME_BASIC) schemes[schemeCount++] = WINHTTP_AUTH_SCHEME_BASIC;

        for (const auto& credentialUser : userCandidates) {
            for (DWORD i = 0; i < schemeCount; ++i) {
                DWORD scheme = schemes[i];
                DWORD ignoredSchemes = 0;
                hr = postOnce(true, credentialUser, scheme, statusCode, ignoredSchemes, response);
                if (FAILED(hr)) {
                    WinHttpCloseHandle(connect);
                    WinHttpCloseHandle(session);
                    return hr;
                }

                if (statusCode >= 200 && statusCode <= 299) {
                    break;
                }

                if (statusCode != HTTP_STATUS_DENIED && statusCode != HTTP_STATUS_BAD_REQUEST) {
                    break;
                }
            }

            if (statusCode >= 200 && statusCode <= 299) {
                break;
            }
        }
    }

    WinHttpCloseHandle(connect);
    WinHttpCloseHandle(session);

    if (statusCode < 200 || statusCode > 299) {
        LogLine(L"HTTP final non-success status=" + std::to_wstring(statusCode));
        if (statusCode == HTTP_STATUS_DENIED) {
            return HRESULT_FROM_WIN32(ERROR_LOGON_FAILURE);
        }
        if (statusCode == HTTP_STATUS_FORBIDDEN) {
            return HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED);
        }
        return HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED);
    }

    LogLine(L"HTTP sign request succeeded.");
    return S_OK;
}

static std::wstring HashAlgorithmFromPadding(void* paddingInfo, DWORD flags)
{
    if ((flags & NCRYPT_PAD_PSS_FLAG) && paddingInfo) {
        auto* info = reinterpret_cast<BCRYPT_PSS_PADDING_INFO*>(paddingInfo);
        return info->pszAlgId ? info->pszAlgId : BCRYPT_SHA256_ALGORITHM;
    }

    if ((flags & NCRYPT_PAD_PKCS1_FLAG) && paddingInfo) {
        auto* info = reinterpret_cast<BCRYPT_PKCS1_PADDING_INFO*>(paddingInfo);
        return info->pszAlgId ? info->pszAlgId : BCRYPT_SHA256_ALGORITHM;
    }

    return BCRYPT_SHA256_ALGORITHM;
}

static HRESULT WINAPI RA3OpenProvider(NCRYPT_PROV_HANDLE* provider, LPCWSTR, DWORD)
{
    if (!provider) {
        return NTE_INVALID_PARAMETER;
    }
    *provider = reinterpret_cast<NCRYPT_PROV_HANDLE>(new (std::nothrow) ProviderContext());
    return *provider ? S_OK : NTE_NO_MEMORY;
}

static HRESULT WINAPI RA3OpenKey(NCRYPT_PROV_HANDLE hProvider, NCRYPT_KEY_HANDLE* key, LPCWSTR keyName, DWORD, DWORD)
{
    ProviderContext* provider = AsProvider(hProvider);
    if (!provider || !key || !keyName) {
        return NTE_INVALID_PARAMETER;
    }

    std::unique_ptr<KeyContext> ctx(new (std::nothrow) KeyContext());
    if (!ctx) {
        return NTE_NO_MEMORY;
    }
    ctx->provider = provider;
    ctx->containerName = keyName;

    if (!LoadKeyConfig(ctx->containerName, *ctx)) {
        return NTE_BAD_KEYSET;
    }

    *key = reinterpret_cast<NCRYPT_KEY_HANDLE>(ctx.release());
    return S_OK;
}

static HRESULT WINAPI RA3GetProviderProperty(NCRYPT_PROV_HANDLE hProvider, LPCWSTR property, PBYTE output, DWORD outputSize, DWORD* result, DWORD)
{
    if (!AsProvider(hProvider) || !property) {
        return NTE_INVALID_PARAMETER;
    }

    if (_wcsicmp(property, NCRYPT_NAME_PROPERTY) == 0) {
        return WriteWideString(kProviderName, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_IMPL_TYPE_PROPERTY) == 0) {
        return WriteDword(NCRYPT_IMPL_SOFTWARE_FLAG | NCRYPT_IMPL_REMOVABLE_FLAG, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_MAX_NAME_LENGTH_PROPERTY) == 0) {
        return WriteDword(512, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_SECURITY_DESCR_SUPPORT_PROPERTY) == 0) {
        return WriteDword(0, output, outputSize, result);
    }

    return NTE_NOT_SUPPORTED;
}

static HRESULT WINAPI RA3GetKeyProperty(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE hKey, LPCWSTR property, PBYTE output, DWORD outputSize, DWORD* result, DWORD)
{
    KeyContext* key = AsKey(hKey);
    if (!key || !property) {
        return NTE_INVALID_PARAMETER;
    }

    if (_wcsicmp(property, NCRYPT_ALGORITHM_PROPERTY) == 0) {
        return WriteWideString(BCRYPT_RSA_ALGORITHM, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_ALGORITHM_GROUP_PROPERTY) == 0) {
        return WriteWideString(NCRYPT_RSA_ALGORITHM_GROUP, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_LENGTH_PROPERTY) == 0) {
        return WriteDword(key->keyLength, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_PUBLIC_LENGTH_PROPERTY) == 0) {
        return WriteDword(key->keyLength, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_SIGNATURE_LENGTH_PROPERTY) == 0) {
        return WriteDword(key->keyLength / 8, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_KEY_USAGE_PROPERTY) == 0) {
        return WriteDword(NCRYPT_ALLOW_SIGNING_FLAG, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_KEY_TYPE_PROPERTY) == 0) {
        return WriteDword(0, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_EXPORT_POLICY_PROPERTY) == 0) {
        return WriteDword(0, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_NAME_PROPERTY) == 0 || _wcsicmp(property, NCRYPT_UNIQUE_NAME_PROPERTY) == 0) {
        return WriteWideString(key->containerName, output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_PROVIDER_HANDLE_PROPERTY) == 0) {
        return WriteHandle(reinterpret_cast<ULONG_PTR>(key->provider), output, outputSize, result);
    }
    if (_wcsicmp(property, NCRYPT_CERTIFICATE_PROPERTY) == 0 && !key->publicCertificateBase64.empty()) {
        std::vector<BYTE> cert;
        HRESULT hr = DecodeBase64(key->publicCertificateBase64, cert);
        if (FAILED(hr)) return hr;
        return WriteOutput(cert.data(), static_cast<DWORD>(cert.size()), output, outputSize, result) ? S_OK : HRESULT_FROM_WIN32(ERROR_MORE_DATA);
    }

    return NTE_NOT_SUPPORTED;
}

static HRESULT WINAPI RA3SetKeyProperty(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE hKey, LPCWSTR property, PBYTE input, DWORD inputSize, DWORD)
{
    KeyContext* key = AsKey(hKey);
    if (!key || !property) {
        return NTE_INVALID_PARAMETER;
    }

    if (_wcsicmp(property, NCRYPT_PIN_PROPERTY) == 0) {
        if (!input || inputSize < sizeof(wchar_t)) {
            return NTE_INVALID_PARAMETER;
        }
        key->cachedPin.assign(reinterpret_cast<wchar_t*>(input), inputSize / sizeof(wchar_t));
        if (!key->cachedPin.empty() && key->cachedPin.back() == L'\0') {
            key->cachedPin.pop_back();
        }
        return S_OK;
    }

    return NTE_NOT_SUPPORTED;
}

static HRESULT WINAPI RA3FreeProvider(NCRYPT_PROV_HANDLE hProvider)
{
    ProviderContext* provider = AsProvider(hProvider);
    if (!provider) {
        return NTE_INVALID_HANDLE;
    }
    provider->magic = 0;
    delete provider;
    return S_OK;
}

static HRESULT WINAPI RA3FreeKey(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE hKey)
{
    KeyContext* key = AsKey(hKey);
    if (!key) {
        return NTE_INVALID_HANDLE;
    }
    if (!key->cachedPin.empty()) {
        SecureZeroMemory(key->cachedPin.data(), key->cachedPin.size() * sizeof(wchar_t));
    }
    if (!key->networkPassword.empty()) {
        SecureZeroMemory(key->networkPassword.data(), key->networkPassword.size() * sizeof(wchar_t));
    }
    key->magic = 0;
    delete key;
    return S_OK;
}

static HRESULT WINAPI RA3FreeBuffer(PVOID buffer)
{
    if (buffer) {
        LocalFree(buffer);
    }
    return S_OK;
}

static HRESULT WINAPI RA3IsAlgSupported(NCRYPT_PROV_HANDLE hProvider, LPCWSTR algId, DWORD)
{
    if (!AsProvider(hProvider) || !algId) {
        return NTE_INVALID_PARAMETER;
    }
    if (_wcsicmp(algId, BCRYPT_RSA_ALGORITHM) == 0 || _wcsicmp(algId, BCRYPT_RSA_SIGN_ALGORITHM) == 0) {
        return S_OK;
    }
    return NTE_BAD_ALGID;
}

static HRESULT WINAPI RA3SignHash(NCRYPT_PROV_HANDLE, NCRYPT_KEY_HANDLE hKey, VOID* paddingInfo, PBYTE hashValue, DWORD hashSize, PBYTE signature, DWORD signatureSize, DWORD* result, DWORD flags)
{
    KeyContext* key = AsKey(hKey);
    if (!key || !hashValue || hashSize == 0 || !result) {
        return NTE_INVALID_PARAMETER;
    }

    DWORD expectedSize = key->keyLength / 8;
    if (!signature) {
        *result = expectedSize;
        return S_OK;
    }
    if (signatureSize < expectedSize) {
        *result = expectedSize;
        return HRESULT_FROM_WIN32(ERROR_MORE_DATA);
    }

    HRESULT hr = PromptForPin(*key, flags);
    if (FAILED(hr)) {
        return hr;
    }

    std::wstring padding = (flags & NCRYPT_PAD_PSS_FLAG) ? L"Pss" : L"Pkcs1";
    std::wstring hashAlg = HashAlgorithmFromPadding(paddingInfo, flags);
    std::wstring digest = EncodeBase64(hashValue, hashSize);

    std::wstring url = key->agentUrl;
    if (!url.empty() && url.back() != L'/') {
        url.push_back(L'/');
    }
    url += L"sign";

    std::wstring json =
        L"{\"thumbprint\":\"" + EscapeJson(key->thumbprint) +
        L"\",\"scope\":\"" + EscapeJson(key->scope) +
        L"\",\"storeName\":\"" + EscapeJson(key->storeName) +
        L"\",\"hashAlgorithm\":\"" + EscapeJson(hashAlg) +
        L"\",\"padding\":\"" + padding +
        L"\",\"digestBase64\":\"" + digest +
        L"\",\"pin\":\"" + EscapeJson(key->cachedPin) + L"\"}";

    std::string response;
    hr = HttpPostJson(url, json, key->networkUser, key->networkPassword, response);
    if (FAILED(hr)) {
        return hr;
    }

    std::wstring signatureBase64 = JsonValue(response, "signatureBase64");
    std::vector<BYTE> decoded;
    hr = DecodeBase64(signatureBase64, decoded);
    if (FAILED(hr)) {
        return hr;
    }

    if (signatureSize < decoded.size()) {
        *result = static_cast<DWORD>(decoded.size());
        return HRESULT_FROM_WIN32(ERROR_MORE_DATA);
    }

    CopyMemory(signature, decoded.data(), decoded.size());
    *result = static_cast<DWORD>(decoded.size());
    return S_OK;
}

static NCRYPT_KEY_STORAGE_FUNCTION_TABLE g_table = {
    { 1, 0 },
    RA3OpenProvider,
    RA3OpenKey,
    nullptr,
    RA3GetProviderProperty,
    RA3GetKeyProperty,
    nullptr,
    RA3SetKeyProperty,
    nullptr,
    nullptr,
    RA3FreeProvider,
    RA3FreeKey,
    RA3FreeBuffer,
    nullptr,
    nullptr,
    RA3IsAlgSupported,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    RA3SignHash,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr
};

extern "C" HRESULT WINAPI GetKeyStorageInterface(LPCWSTR, NCRYPT_KEY_STORAGE_FUNCTION_TABLE** table, DWORD)
{
    if (!table) {
        return NTE_INVALID_PARAMETER;
    }
    *table = &g_table;
    return S_OK;
}
