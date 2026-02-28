//
//  Error-View.swift
//  Stingray
//
//  Created by Ben Roberts on 1/26/26.
//

import SwiftUI

/// Shows a simple error and can expand into a full verbose error log.
public struct ErrorView: View {
    /// Recursive error thrown by Stingray
    let error: RError
    /// User-facing error to show before expanding
    let summary: String
    /// Tracks whether or not the error has been expanded
    @State private var isExpanded: Bool = false

    public var body: some View {
        Button { self.isExpanded = true }
        label: { ErrorSummaryView(summary: summary) }
            .buttonStyle(.plain)
            .padding(.horizontal, 70)
            .sheet(isPresented: $isExpanded) { ErrorExpandedView(errorDesc: error.rDescription) }
    }
}

/// Show a summary of a greater error.
fileprivate struct ErrorSummaryView: View {
    /// User-facing error to show before expanding
    let summary: String

    var body: some View {
        HStack(spacing: StingraySpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text(summary)
                .foregroundStyle(StingrayColors.textPrimary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(StingrayColors.errorTint)
        }
        .glassBackground(cornerRadius: 20, padding: 0)
    }
}

/// Show a verbose version of an RError
public struct ErrorExpandedView: View {
    /// Verbose error thrown by Stingray
    let errorDesc: () -> String

    public var body: some View {
        VStack(alignment: .leading) {
            Text("Error:")
                .font(StingrayFont.sectionTitle)
            Text(errorDesc())
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 20)
    }
}

#Preview {
    ErrorSummaryView(summary: "Stingray went kaplooey.")
}

#Preview {
    ErrorSummaryView(summary: "Stingray went kaplooey.")
        .sheet(isPresented: .constant(true)) {
            ErrorExpandedView(errorDesc: NetworkError.decodeJSONFailed(JSONError.missingKey("Nerd", "Preview"), url: nil).rDescription)
        }
}
