
// QuantumultX Script to check SSID and redirect
const ssid = $network.wifi.ssid;
const targetSSID = "Apple"; // Replace with your SSID

if (ssid === targetSSID) {
    const newUrl = "http://192.168.1.215" + $request.path;
    $done({ response: { status: 302, headers: { Location: newUrl } } });
} else {
    $done({});
}
