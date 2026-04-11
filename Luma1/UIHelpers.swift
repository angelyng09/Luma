//
//  UIHelpers.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import SwiftUI

enum LumaPalette {
    static let backgroundTop = Color(red: 0.99, green: 0.95, blue: 0.82)
    static let backgroundBottom = Color(red: 0.97, green: 0.91, blue: 0.72)
    static let card = Color(red: 0.99, green: 0.97, blue: 0.90)
    static let cardBorder = Color(red: 0.81, green: 0.70, blue: 0.50)
    static let input = Color.white
    static let inputBorder = Color(red: 0.76, green: 0.66, blue: 0.50)
    static let primaryText = Color(red: 0.23, green: 0.18, blue: 0.11)
    static let secondaryText = Color(red: 0.42, green: 0.33, blue: 0.21)
    static let accent = Color(red: 0.85, green: 0.56, blue: 0.29)
    static let accentPressed = Color(red: 0.73, green: 0.44, blue: 0.20)
    static let accentSoft = Color(red: 0.95, green: 0.82, blue: 0.56)
    static let waveLight = Color(red: 0.98, green: 0.85, blue: 0.56)
    static let waveMid = Color(red: 0.93, green: 0.71, blue: 0.40)
    static let waveDark = Color(red: 0.82, green: 0.56, blue: 0.30)
}

private struct LumaWaveMotif: View {
    let mirrored: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(LumaPalette.waveDark.opacity(0.36))
                .frame(width: 200, height: 24)
                .offset(y: -20)
            Capsule()
                .fill(LumaPalette.waveMid.opacity(0.42))
                .frame(width: 240, height: 24)
            Capsule()
                .fill(LumaPalette.waveLight.opacity(0.54))
                .frame(width: 280, height: 24)
                .offset(y: 20)
        }
        .rotationEffect(.degrees(mirrored ? 18 : -18))
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .blur(radius: 0.4)
        .accessibilityHidden(true)
    }
}

private struct LumaScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LumaPalette.backgroundTop, LumaPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            LumaWaveMotif(mirrored: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 72, y: 52)

            LumaWaveMotif(mirrored: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -72, y: -68)
        }
        .ignoresSafeArea()
    }
}

private struct LumaScreenStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(LumaPalette.accent)
            .foregroundStyle(LumaPalette.primaryText)
            .background {
                LumaScreenBackground()
            }
    }
}

struct LumaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(LumaPalette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? LumaPalette.accentPressed : LumaPalette.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LumaPalette.accent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct LumaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(LumaPalette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? LumaPalette.card.opacity(0.84) : LumaPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LumaPalette.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct LumaInlineIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LumaPalette.primaryText)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? LumaPalette.accentSoft.opacity(0.88) : LumaPalette.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumaPalette.accent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct LumaCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(LumaPalette.primaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? LumaPalette.card.opacity(0.84) : LumaPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumaPalette.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct LumaCompactPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(LumaPalette.primaryText)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? LumaPalette.accentPressed : LumaPalette.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumaPalette.accent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func emailInputBehavior() -> some View {
        #if os(iOS)
        self
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func usernameInputBehavior() -> some View {
        #if os(iOS)
        self
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func passwordInputBehavior() -> some View {
        #if os(iOS)
        self.textContentType(.password)
        #else
        self
        #endif
    }

    @ViewBuilder
    func lumaScreenStyle() -> some View {
        self.modifier(LumaScreenStyleModifier())
    }

    @ViewBuilder
    func lumaCardStyle(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LumaPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LumaPalette.cardBorder.opacity(0.9), lineWidth: 1)
            )
    }

    @ViewBuilder
    func lumaInputStyle() -> some View {
        self
            .foregroundColor(.black)
            .tint(.black)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LumaPalette.input)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LumaPalette.inputBorder.opacity(0.82), lineWidth: 1)
            )
    }
}

var inputBackgroundColor: Color {
    LumaPalette.input
}
