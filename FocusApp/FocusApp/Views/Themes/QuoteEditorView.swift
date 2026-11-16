import SwiftUI

struct QuoteEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let target: QuoteEditTarget
    @State private var text: String
    @FocusState private var focused: Bool

    private let maxLength = 160

    init(target: QuoteEditTarget) {
        self.target = target
        _text = State(initialValue: target.quote?.text ?? "")
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                TextEditor(text: $text)
                    .focused($focused)
                    .font(.system(size: 21, design: .serif))
                    .foregroundStyle(DS.Palette.text)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(height: 190)
                    .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .strokeBorder(DS.Palette.stroke, lineWidth: 1)
                    )
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength { text = String(newValue.prefix(maxLength)) }
                    }

                HStack {
                    Text("Shown on your block screen and Live Activity.")
                    Spacer()
                    Text("\(text.count)/\(maxLength)").monospacedDigit()
                }
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Palette.tertiary)

                if let quote = target.quote {
                    Button("Delete quote") {
                        model.deleteQuote(quote)
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle(foreground: DS.Palette.danger))
                    .padding(.top, DS.Space.s)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Space.gutter)
            .padding(.top, DS.Space.m)
            .background(DS.Palette.background.ignoresSafeArea())
            .navigationTitle(target.quote == nil ? "New quote" : "Edit quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.Palette.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let quote = target.quote {
                            model.updateQuote(quote, text: trimmed)
                        } else {
                            model.addQuote(trimmed)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(trimmed.isEmpty ? DS.Palette.tertiary : DS.Palette.text)
                    .disabled(trimmed.isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(DS.Palette.background)
    }
}
