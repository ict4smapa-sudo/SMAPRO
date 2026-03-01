import Flutter
import UIKit

// =============================================================================
// File     : AppDelegate.swift
// Fungsi   : Entry point aplikasi iOS + MethodChannel untuk Guided Access.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 11.2 — iOS Guided Access Detection via Platform Channel
//
// MethodChannel : "com.sman4jember.exambro/security"
// Method        : "checkGuidedAccess" → returns Bool
// =============================================================================

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Channel name wajib identik dengan yang digunakan di SecurityHelper.dart
  private let channelName = "com.sman4jember.exambro/security"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Daftarkan semua plugin Flutter
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // -------------------------------------------------------------------------
    // Daftarkan MethodChannel untuk Guided Access Detection
    // Menggunakan Binary Messenger dari engine yang sudah diinisialisasi.
    // -------------------------------------------------------------------------
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "SecurityPlugin")?.messenger() else { return }

    let securityChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    securityChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "checkGuidedAccess":
        // Kembalikan true jika Guided Access AKTIF, false jika belum aktif.
        // UIAccessibility.isGuidedAccessEnabled adalah API resmi Apple (tidak perlu Entitlement).
        let isEnabled = UIAccessibility.isGuidedAccessEnabled
        result(isEnabled)

      default:
        // Method tidak dikenal — kembalikan FlutterMethodNotImplemented
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
