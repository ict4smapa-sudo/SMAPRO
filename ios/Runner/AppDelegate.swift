import Flutter
import UIKit

// =============================================================================
// File     : AppDelegate.swift
// Fungsi   : Entry point aplikasi iOS.
//             Mendaftarkan dua MethodChannel:
//               1. "id.sman4jember.exambro/kiosk"    → isGuidedAccessEnabled
//               2. "com.sman4jember.exambro/security" → checkGuidedAccess (lama)
// Tanggal  : 27 Februari 2026 | Update: 01 Maret 2026
// PRD Ref  : Section 11.2 — iOS Guided Access Detection via Platform Channel
// =============================================================================

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let messenger = controller.binaryMessenger

    // -------------------------------------------------------------------------
    // CHANNEL 1: id.sman4jember.exambro/kiosk
    // Channel utama — digunakan SecurityHelper.dart (_kioskChannel).
    // Method: "isGuidedAccessEnabled" → Bool
    // -------------------------------------------------------------------------
    let kioskChannel = FlutterMethodChannel(
      name: "id.sman4jember.exambro/kiosk",
      binaryMessenger: messenger
    )

    kioskChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isGuidedAccessEnabled":
        // Menggunakan API resmi Apple — tidak membutuhkan Entitlement khusus.
        result(UIAccessibility.isGuidedAccessEnabled)
      default:
        // enableKioskMode / disableKioskMode tidak relevan di iOS — kembalikan success
        result(nil)
      }
    }

    // -------------------------------------------------------------------------
    // CHANNEL 2: com.sman4jember.exambro/security
    // Channel lama — dipertahankan untuk backward compatibility.
    // Method: "checkGuidedAccess" → Bool (identik dengan isGuidedAccessEnabled)
    // -------------------------------------------------------------------------
    let securityChannel = FlutterMethodChannel(
      name: "com.sman4jember.exambro/security",
      binaryMessenger: messenger
    )

    securityChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "checkGuidedAccess":
        result(UIAccessibility.isGuidedAccessEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

