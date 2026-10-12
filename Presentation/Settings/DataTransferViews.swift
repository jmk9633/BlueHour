//
//  DataTransferViews.swift
//  BlueHour
//
//  데이터 내보내기/가져오기에서 쓰는 UIKit 브리지(공유 시트·파일 선택기)와 내보내기 옵션 시트.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 공유 시트 (UIActivityViewController)

/// 만든 ZIP 파일을 iOS 공유 시트로 전달한다. 닫히면 onComplete로 임시 파일 정리를 알린다.
struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 파일 선택기 (.zip)

/// .zip 파일 하나를 고르는 선택기. 고른 파일 경로를 onPick으로 전달한다.
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - 내보내기 옵션 시트

/// 목소리가 남은 기록이 있을 때 '목소리도 함께 담기'를 고르고 내보낸다.
struct ExportOptionsSheet: View {
    @Bindable var controller: DataTransferController
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BHMetrics.spacingL) {
            Text("데이터 내보내기")
                .font(.bhHeadline)
                .foregroundStyle(Color.bhTextPrimary)

            Toggle("목소리도 함께 담기", isOn: $controller.includeVoice)
                .font(.bhBody)
                .tint(Color.bhAccent)

            Button("내보내기") {
                onExport()
            }
            .buttonStyle(.bhPrimary)
        }
        .padding(BHMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bhBackground)
        .presentationDetents([.height(220)])
    }
}
