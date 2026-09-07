import XCTest
import SwiftUI
import CoreAudio
@testable import CustomVolumeHUDLib

final class CustomVolumeHUDTests: XCTestCase {

    // MARK: - Volume Slot Calculation Tests

    func testSlotCountCalculation() {
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.0), 0)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.04), 0)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.05), 1)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.10), 1)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.20), 2)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.50), 5)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.80), 8)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.94), 9)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 0.96), 10)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 1.0), 10)
        // Boundary / clamping tests
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: -0.5), 0)
        XCTAssertEqual(VolumeHUDViewModel.calculateSlotCount(for: 1.5), 10)
    }

    // MARK: - ViewModel State & Immediate Transitions

    @MainActor
    func testImmediateUpdate() {
        let vm = VolumeHUDViewModel(volume: 0.3, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 3)
        XCTAssertEqual(vm.targetSlotCount, 3)
        XCTAssertFalse(vm.isMuted)

        vm.update(volume: 0.8, isMuted: false, animated: false)
        XCTAssertEqual(vm.displayedCount, 8)
        XCTAssertEqual(vm.targetSlotCount, 8)
        XCTAssertEqual(vm.slotOpacities[0], 1.0)
        XCTAssertEqual(vm.slotOpacities[7], 1.0)
        XCTAssertEqual(vm.slotOpacities[8], 0.0)

        // Mute immediate clear
        vm.update(volume: 0.8, isMuted: true, animated: false)
        XCTAssertEqual(vm.displayedCount, 0)
        XCTAssertEqual(vm.targetSlotCount, 0)
        XCTAssertTrue(vm.isMuted)
    }

    // MARK: - Animation Engine: Sequential Reveal (Volume Up)

    @MainActor
    func testVolumeUpSequentialReveal() {
        let vm = VolumeHUDViewModel(volume: 0.2, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 2)

        let expectation = XCTestExpectation(description: "Sequential reveal reaches target")

        // Step up from 2 to 5
        vm.update(volume: 0.5, isMuted: false, animated: true)

        // After 250 ms, all 5 slots should be active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(vm.displayedCount, 5)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Animation Engine: Rapid Dissolve (Volume Down)

    @MainActor
    func testVolumeDownRapidDissolve() {
        let vm = VolumeHUDViewModel(volume: 0.8, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 8)

        let expectation = XCTestExpectation(description: "Rapid dissolve reaches target")

        // Step down from 8 to 3
        vm.update(volume: 0.3, isMuted: false, animated: true)

        // After 200 ms, slots should dissolve down to 3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            XCTAssertEqual(vm.displayedCount, 3)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Animation Engine: Mute Immediate Clear & Silence Reaction

    @MainActor
    func testMuteImmediateClearAndSilenceReaction() {
        let vm = VolumeHUDViewModel(volume: 0.7, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 7)

        // Mute
        vm.update(volume: 0.7, isMuted: true, animated: true)

        // COOLs must clear IMMEDIATELY
        XCTAssertEqual(vm.displayedCount, 0, "Muting must clear all COOL slots immediately")
        XCTAssertNil(vm.holtSpeech, "Holt speech should not be displayed immediately")

        let expectation = XCTestExpectation(description: "Holt silence reaction displays after ~300 ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            XCTAssertNotNil(vm.holtSpeech, "Holt should display silence reaction after 300 ms")
            XCTAssertTrue(["Silence.", "Finally."].contains(vm.holtSpeech))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Animation Engine: Unmute Sequence Rebuild

    @MainActor
    func testUnmuteRebuild() {
        let vm = VolumeHUDViewModel(volume: 0.6, isMuted: true)
        XCTAssertEqual(vm.displayedCount, 0)

        let expectation = XCTestExpectation(description: "Unmute rebuilds sequence within 400 ms")

        // Unmute
        vm.update(volume: 0.6, isMuted: false, animated: true)

        // Holt speech should clear immediately on unmute
        XCTAssertNil(vm.holtSpeech)

        // At 380 ms, all 6 slots should be rebuilt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            XCTAssertEqual(vm.displayedCount, 6)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Rapid Tapping Catch-up (< 150 ms)

    @MainActor
    func testRapidTappingCatchUp() {
        let vm = VolumeHUDViewModel(volume: 0.1, isMuted: false)

        // Simulate rapid key taps
        vm.update(volume: 0.3, isMuted: false, animated: true)
        vm.update(volume: 0.6, isMuted: false, animated: true)
        vm.update(volume: 0.9, isMuted: false, animated: true)

        let expectation = XCTestExpectation(description: "Rapid volume catches up in < 150 ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            XCTAssertEqual(vm.displayedCount, 9, "Animation engine must catch up to authoritative volume in < 150 ms")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Character Personality & Easter Eggs at 100%

    @MainActor
    func testMaxVolumeCelebrationAndEasterEggs() {
        let vm = VolumeHUDViewModel(volume: 0.5, isMuted: false)

        // Jump to 100%
        vm.update(volume: 1.0, isMuted: false, animated: true)

        XCTAssertNotNil(vm.jakeSpeech, "Jake should trigger an Easter egg exclamation at 100%")
        let validJakeEggs = ["BINGPOT!", "NO DOUBT!", "COOL COOL COOL!"]
        XCTAssertTrue(validJakeEggs.contains(vm.jakeSpeech!))
        XCTAssertLessThan(vm.jakeBounceY, 0, "Jake should celebratory bounce at 100%")
    }

    // MARK: - Pixel Font Engine Tests

    func testPixelFontGlyphs() {
        let coolLetters: [Character] = ["C", "O", "L", "!"]
        for char in coolLetters {
            let mask = PixelFont.glyph(for: char)
            XCTAssertEqual(mask.count, 7, "Each glyph must have 7 rows")
            for row in mask {
                XCTAssertLessThanOrEqual(row, 0b11111, "Row bits must fit in 5 columns")
            }
        }

        // Test fallback for unknown character
        let fallback = PixelFont.glyph(for: "@")
        XCTAssertEqual(fallback.count, 7)
    }

    // MARK: - Asset Loading Tests

    func testPixelSpriteAssetsExistAndLoad() {
        let loader = PixelAssetLoader.shared

        let jake = loader.image(named: "jake")
        XCTAssertNotNil(jake, "jake.png must be loadable")
        if let jake = jake {
            XCTAssertGreaterThan(jake.size.width, 0)
            XCTAssertGreaterThan(jake.size.height, 0)
        }

        let holt = loader.image(named: "holt")
        XCTAssertNotNil(holt, "holt.png must be loadable")
        if let holt = holt {
            XCTAssertGreaterThan(holt.size.width, 0)
            XCTAssertGreaterThan(holt.size.height, 0)
        }

        let holtEyebrow = loader.image(named: "holt_eyebrow")
        XCTAssertNotNil(holtEyebrow, "holt_eyebrow.png must be loadable")
        if let holtEyebrow = holtEyebrow {
            XCTAssertGreaterThan(holtEyebrow.size.width, 0)
            XCTAssertGreaterThan(holtEyebrow.size.height, 0)
        }
    }

    func testBluetoothDeviceClassificationAndAssets() {
        let airPods = BluetoothOutputDevice(name: "Saumya's AirPods Pro", batteryPercentage: 84)
        XCTAssertEqual(airPods.kind, .earbuds)
        XCTAssertEqual(airPods.displayName, "AIRPODS PRO")
        XCTAssertEqual(airPods.batteryPercentage, 84)

        let headphones = BluetoothOutputDevice(name: "WH-1000XM5")
        XCTAssertEqual(headphones.kind, .headphones)
        XCTAssertEqual(headphones.displayName, "WH-1000XM5")

        XCTAssertNotNil(PixelAssetLoader.shared.image(named: airPods.assetName))
        XCTAssertNotNil(PixelAssetLoader.shared.image(named: headphones.assetName))
    }

    @MainActor
    func testBluetoothOutputUpdatesAndRendersInHUD() {
        let airPods = BluetoothOutputDevice(name: "Saumya's AirPods Pro", batteryPercentage: 84)
        let vm = VolumeHUDViewModel(
            volume: 0.7,
            isMuted: false,
            bluetoothOutputDevice: airPods
        )
        vm.beginSession(sceneMode: .coolHolt)
        XCTAssertEqual(vm.bluetoothOutputDevice, airPods)

        renderViewToPNG(
            view: VolumeHUDView(viewModel: vm),
            filename: "hud_preview_airpods_70.png"
        )

        let headphonesVM = VolumeHUDViewModel(
            volume: 0.65,
            isMuted: false,
            bluetoothOutputDevice: BluetoothOutputDevice(name: "WH-1000XM5", batteryPercentage: 12)
        )
        headphonesVM.beginSession(sceneMode: .runToTerry)
        headphonesVM.update(volume: 0.65, isMuted: false, animated: false)
        renderViewToPNG(
            view: VolumeHUDView(viewModel: headphonesVM),
            filename: "hud_preview_headphones_65.png"
        )
        headphonesVM.endSession()

        vm.update(volume: 0.6, isMuted: false, animated: false, bluetoothOutputDevice: nil)
        XCTAssertNil(vm.bluetoothOutputDevice)
        vm.endSession()
    }

    func testModifierRoutingKeepsFineStepsDistinctFromOutputCycling() {
        XCTAssertTrue(MediaKeyInterceptor.isFineAdjustment(shiftPressed: true, optionPressed: true))
        XCTAssertFalse(MediaKeyInterceptor.shouldCycleOutput(shiftPressed: true, optionPressed: true))
        XCTAssertTrue(MediaKeyInterceptor.shouldCycleOutput(shiftPressed: false, optionPressed: true))
        XCTAssertFalse(MediaKeyInterceptor.shouldCycleOutput(shiftPressed: true, optionPressed: false))
        XCTAssertEqual(
            MediaKeyInterceptor.fineVolumeStep,
            MediaKeyInterceptor.standardVolumeStep / 4,
            accuracy: 0.000_001
        )
    }

    func testAudioOutputCyclingWrapsInBothDirections() {
        XCTAssertEqual(AudioOutputDevice.cycledIndex(currentIndex: 2, count: 3, direction: 1), 0)
        XCTAssertEqual(AudioOutputDevice.cycledIndex(currentIndex: 0, count: 3, direction: -1), 2)
        XCTAssertEqual(AudioOutputDevice.cycledIndex(currentIndex: 1, count: 3, direction: 1), 2)
        XCTAssertNil(AudioOutputDevice.cycledIndex(currentIndex: 0, count: 0, direction: 1))
    }

    func testChiptuneWaveformsAreFiniteNonSilentAndCueSpecific() {
        let up = ChiptuneSynthesizer.samples(for: .stepUp)
        let down = ChiptuneSynthesizer.samples(for: .stepDown)
        let fanfare = ChiptuneSynthesizer.samples(for: .maximum)
        let mute = ChiptuneSynthesizer.samples(for: .mute)

        for samples in [up, down, fanfare, mute] {
            XCTAssertFalse(samples.isEmpty)
            XCTAssertTrue(samples.allSatisfy(\.isFinite))
            XCTAssertTrue(samples.contains { abs($0) > 0.001 })
            XCTAssertLessThanOrEqual(samples.map { abs($0) }.max() ?? 0, 1)
        }
        XCTAssertNotEqual(up, down)
        XCTAssertGreaterThan(fanfare.count, up.count)
        XCTAssertGreaterThan(mute.count, down.count)
    }

    func testBatteryExtractionSupportsSingleAndSplitEarbuds() {
        XCTAssertEqual(
            BluetoothBatteryReader.percentage(in: ["BatteryPercent": 84]),
            84
        )
        XCTAssertEqual(
            BluetoothBatteryReader.percentage(in: [
                "Product": "AirPods Pro",
                "Battery": [
                    "BatteryPercentLeft": 0.84,
                    "BatteryPercentRight": 72,
                    "BatteryPercentCase": 5
                ]
            ]),
            72
        )
        XCTAssertNil(BluetoothBatteryReader.percentage(in: ["Unrelated": 50]))
        XCTAssertEqual(BluetoothOutputDevice(name: "AirPods", batteryPercentage: 140).batteryPercentage, 100)
    }

    @MainActor
    func testFineAdjustmentTriggersJakeMicroShuffle() {
        let vm = VolumeHUDViewModel(volume: 0.5, isMuted: false)
        vm.beginSession(sceneMode: .coolHolt)
        vm.update(
            volume: 0.5 + MediaKeyInterceptor.fineVolumeStep,
            isMuted: false,
            inputAction: .fineVolumeUp
        )

        XCTAssertTrue(vm.isFineAdjustment)
        XCTAssertGreaterThan(vm.jakeMicroOffsetX, 0)
        XCTAssertLessThan(vm.jakeMicroTiptoeY, 0)
        renderViewToPNG(view: VolumeHUDView(viewModel: vm), filename: "hud_preview_fine_51.png")
        vm.endSession()
    }

    @MainActor
    func testOutputSwitchAnnouncementSurvivesCoreAudioEcho() {
        let studioDisplay = AudioOutputDevice(
            id: 42,
            name: "Studio Display",
            transportType: kAudioDeviceTransportTypeDisplayPort
        )
        let vm = VolumeHUDViewModel(volume: 0.5, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)
        vm.update(
            volume: 0.5,
            isMuted: false,
            inputAction: .outputNext,
            bluetoothOutputDevice: nil,
            outputDevice: studioDisplay
        )
        XCTAssertEqual(vm.outputSwitchDevice, studioDisplay)
        renderViewToPNG(
            view: VolumeHUDView(viewModel: vm),
            filename: "hud_preview_output_switch.png"
        )

        vm.update(
            volume: 0.5,
            isMuted: false,
            inputAction: .externalChange,
            bluetoothOutputDevice: nil
        )
        XCTAssertEqual(vm.outputSwitchDevice, studioDisplay)
        vm.endSession()
        XCTAssertNil(vm.outputSwitchDevice)
    }

    // MARK: - HUD Layout Dimensions & Visual Snapshot Tests

    @MainActor
    func testHUDControllerDimensions() {
        let controller = HUDWindowController()
        XCTAssertGreaterThanOrEqual(controller.hudWidth, 480)
        XCTAssertLessThanOrEqual(controller.hudWidth, 600)
        XCTAssertGreaterThanOrEqual(controller.hudHeight, 95)
        XCTAssertLessThanOrEqual(controller.hudHeight, 120)
    }

    @MainActor
    func testRenderHUDSnapshots() throws {
        // Render 70% volume state
        let vm70 = VolumeHUDViewModel(volume: 0.7, isMuted: false)
        vm70.update(volume: 0.7, isMuted: false, animated: false)
        renderViewToPNG(view: VolumeHUDView(viewModel: vm70), filename: "hud_preview_70.png")

        // Render 100% volume state with Jake Easter Egg
        let vm100 = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        vm100.update(volume: 1.0, isMuted: false, animated: false)
        vm100.setJakeSpeechForTesting("BINGPOT!")
        renderViewToPNG(view: VolumeHUDView(viewModel: vm100), filename: "hud_preview_100.png")

        // Render Muted state with Holt Silence reaction
        let vmMute = VolumeHUDViewModel(volume: 0.5, isMuted: true)
        vmMute.update(volume: 0.5, isMuted: true, animated: false)
        renderViewToPNG(view: VolumeHUDView(viewModel: vmMute), filename: "hud_preview_muted.png")
    }

    @MainActor
    private func renderViewToPNG<V: View>(view: V, filename: String) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: VolumeHUDView.hudWidth, height: VolumeHUDView.hudHeight)
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }

        let outPath = "/Users/saumya/CustomVolumeHUD/\(filename)"
        try? pngData.write(to: URL(fileURLWithPath: outPath))
    }

    // MARK: - New Robustness & Regression Tests

    func testExtendedPixelFontGlyphs() {
        let punctuation: [Character] = [",", "'", "\"", "(", ")", ";"]
        for char in punctuation {
            let mask = PixelFont.glyph(for: char)
            XCTAssertEqual(mask.count, 7, "Punctuation '\(char)' must have 7 rows")
            for row in mask {
                XCTAssertLessThanOrEqual(row, 0b11111, "Punctuation '\(char)' row bits must fit in 5 columns")
            }
        }
    }

    func testVolumeManagerEchoSuppressionTimestamp() {
        let vm = VolumeManager.shared
        let before = CACurrentMediaTime()
        vm.stepUp()
        let after = vm.lastDirectAdjustmentTimestamp
        XCTAssertGreaterThanOrEqual(after, before, "stepUp() must record direct adjustment timestamp")

        vm.stepDown()
        XCTAssertGreaterThanOrEqual(vm.lastDirectAdjustmentTimestamp, after, "stepDown() must update direct adjustment timestamp")

        vm.toggleMute()
        XCTAssertGreaterThanOrEqual(vm.lastDirectAdjustmentTimestamp, after, "toggleMute() must update direct adjustment timestamp")
    }

    @MainActor
    func testRepeatedPressAtMaxVolumeTriggersCelebration() {
        let vm = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 10)

        // Tapping Volume Up while ALREADY at 100%
        vm.update(volume: 1.0, isMuted: false, animated: true)

        XCTAssertNotNil(vm.jakeSpeech, "Repeated press at 100% must evaluate Jake Easter eggs")
        XCTAssertLessThan(vm.jakeBounceY, 0, "Repeated press at 100% must trigger celebratory bounce")
    }

    @MainActor
    func testNearestNeighborRetinaBackingPolicy() {
        let view = NearestNeighborImageView()
        XCTAssertEqual(view.layerContentsRedrawPolicy, .onSetNeedsDisplay, "Nearest neighbor view must redraw on setNeedsDisplay to maintain Retina sharpness")
        XCTAssertEqual(view.layer?.magnificationFilter, .nearest)
        XCTAssertEqual(view.layer?.minificationFilter, .nearest)
    }

    @MainActor
    func testHUDWindowLevelIsStatusBar() {
        let controller = HUDWindowController()
        // Ensure controller panel is initialized
        controller.show(volume: 0.5, isMuted: false)
    }

    func testVolumeDownUnmutesAudio() {
        let manager = VolumeManager.shared
        manager.isMuted = true
        XCTAssertTrue(manager.isMuted)

        manager.stepDown()
        XCTAssertFalse(manager.isMuted, "Stepping volume down must unmute audio like macOS system behavior")
    }

    @MainActor
    func testAnimationCancellationSanitizesBouncesAndOpacities() {
        let vm = VolumeHUDViewModel(volume: 0.2, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 2)

        // Trigger step up towards 8
        vm.update(volume: 0.8, isMuted: false, animated: true)

        // Immediately interrupt with rapid step down to 4
        vm.update(volume: 0.4, isMuted: false, animated: true)

        // Immediately interrupt with mute
        vm.update(volume: 0.4, isMuted: true, animated: true)

        // Bounces must all be 0.0 and opacities must all be 0.0 when muted
        for i in 0..<VolumeHUDViewModel.maxSlots {
            XCTAssertEqual(vm.slotBounces[i], 0.0, "Slot bounce \(i) must be cleanly reset on cancellation")
            XCTAssertEqual(vm.slotOpacities[i], 0.0, "Slot opacity \(i) must be 0.0 when muted")
        }
        XCTAssertEqual(vm.jakeBounceY, 0.0, "Jake bounce must be reset to 0.0")
    }

    @MainActor
    func testJakeSpeechClearedWhenSteppingBelowMaxVolume() {
        let vm = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        vm.update(volume: 1.0, isMuted: false, animated: true)
        XCTAssertNotNil(vm.jakeSpeech)

        // Step down to 70%
        vm.update(volume: 0.7, isMuted: false, animated: true)
        XCTAssertNil(vm.jakeSpeech, "Jake speech must be cleared when stepping below 100%")

        // Simulate Jake speech and step up to 80%
        vm.setJakeSpeechForTesting("COOL COOL COOL!")
        vm.update(volume: 0.8, isMuted: false, animated: true)
        XCTAssertNil(vm.jakeSpeech, "Jake speech must be cleared when stepping up to a volume < 100%")
    }

    @MainActor
    func testRapidSingleStepDoesNotStall() {
        let vm = VolumeHUDViewModel(volume: 0.3, isMuted: false)
        // First tap
        vm.update(volume: 0.4, isMuted: false, animated: true)

        // Rapid subsequent tap (timeSinceLast < 0.20s)
        vm.update(volume: 0.5, isMuted: false, animated: true)

        let exp = XCTestExpectation(description: "Rapid single-step finishes in < 60ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            XCTAssertEqual(vm.displayedCount, 5, "Single step rapid tap should complete in < 60ms")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - Round 3 Audit & Robustness Tests

    func testSlotTextDimensionsFitWithinSlotBoxWithoutClipping() {
        let text = "COOL"
        let pixelSize: CGFloat = VolumeHUDView.slotPixelSize
        let letterSpacing: CGFloat = VolumeHUDView.slotLetterSpacing
        let charCount = CGFloat(text.count)
        let glyphWidth = 5.0 * pixelSize
        let baseWidth = (charCount * glyphWidth) + ((charCount - 1) * letterSpacing)
        let totalWidth = baseWidth + 1.0 // with shadow
        let totalHeight = (7.0 * pixelSize) + 1.0

        let boxWidth: CGFloat = VolumeHUDView.slotWidth
        let boxHeight: CGFloat = VolumeHUDView.slotHeight

        XCTAssertLessThan(totalWidth, boxWidth, "COOL text width must be strictly less than slot box width")
        XCTAssertLessThan(totalHeight, boxHeight, "COOL text height must be strictly less than slot box height")

        let horizontalMargin = (boxWidth - totalWidth) / 2.0
        let verticalMargin = (boxHeight - totalHeight) / 2.0
        XCTAssertGreaterThanOrEqual(horizontalMargin, 2.0, "Horizontal margin must be at least 2px to avoid border overlap")
        XCTAssertGreaterThanOrEqual(verticalMargin, 4.0, "Vertical margin must be at least 4px for balanced vertical alignment")
    }

    @MainActor
    func testPhosphorFlickerOpacitySetDuringDissolve() {
        let vm = VolumeHUDViewModel(volume: 0.5, isMuted: false)
        XCTAssertEqual(vm.displayedCount, 5)

        // Step down towards 3
        vm.update(volume: 0.3, isMuted: false, animated: true)

        // At 10 ms into the dissolve, slot 4 should be flickering at 0.35 opacity
        let exp = XCTestExpectation(description: "Slot 4 flickers at 0.35 opacity")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.010) {
            XCTAssertEqual(vm.slotOpacities[4], 0.35, "Dissolving slot must enter 0.35 phosphor flicker before extinguishing")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    @MainActor
    func testHUDWindowControllerHideAndProgrammaticDismiss() {
        let controller = HUDWindowController()
        controller.show(volume: 0.5, isMuted: false)

        // Call programmatic hide
        controller.hide()

        // Immediate re-show must work without failure
        controller.show(volume: 0.7, isMuted: false)
    }

    func testPixelAssetLoaderThreadSafety() {
        let loader = PixelAssetLoader.shared
        let expectation = XCTestExpectation(description: "Concurrent sprite asset loading completes without data race")
        expectation.expectedFulfillmentCount = 20

        DispatchQueue.concurrentPerform(iterations: 20) { i in
            let name = (i % 2 == 0) ? "jake" : "holt"
            let img = loader.image(named: name)
            XCTAssertNotNil(img, "Asset \(name) must be loaded safely concurrently")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMuteKeyRepeatSuppressionLogic() {
        // keyState == 0x0A (key down / repeat)
        let initialPressFlags = 0x0A00 // bit 0 is 0
        let repeatPressFlags = 0x0A01  // bit 0 is 1

        let isRepeatInitial = (initialPressFlags & 0x1) != 0
        let isRepeatHeld = (repeatPressFlags & 0x1) != 0

        XCTAssertFalse(isRepeatInitial, "Initial key press must not be identified as repeat")
        XCTAssertTrue(isRepeatHeld, "Held key press must be identified as repeat")
    }

    // MARK: - Continuous Momentum & Physics Tests

    func testContinuousInputVelocityDecay() {
        let tracker = InputVelocityTracker()
        tracker.recordEvent(direction: 1)
        XCTAssertGreaterThan(tracker.inputIntensity, 0.0)

        // Multiple rapid events scale up intensity
        tracker.recordEvent(direction: 1)
        tracker.recordEvent(direction: 1)
        XCTAssertGreaterThanOrEqual(tracker.inputIntensity, 0.5)

        // Ticking deltaTime decays intensity
        let initialIntensity = tracker.inputIntensity
        tracker.update(deltaTime: 0.15)
        XCTAssertLessThan(tracker.inputIntensity, initialIntensity)

        // Longer delay completely extinguishes intensity
        tracker.update(deltaTime: 1.0)
        XCTAssertEqual(tracker.inputIntensity, 0.0)
    }

    func testComboCounterIncrementAndReset() {
        let tracker = InputVelocityTracker()
        tracker.recordEvent(direction: 1)
        XCTAssertEqual(tracker.comboCount, 1)

        tracker.recordEvent(direction: 1)
        XCTAssertEqual(tracker.comboCount, 2)

        tracker.recordEvent(direction: 1)
        XCTAssertEqual(tracker.comboCount, 3)

        // Exceed combo timeout (350 ms)
        tracker.update(deltaTime: 0.40)
        XCTAssertEqual(tracker.comboCount, 0)
    }

    @MainActor
    func testJakeExcitementContinuousInterpolation() {
        let vm = VolumeHUDViewModel(volume: 0.2, isMuted: false)
        XCTAssertGreaterThanOrEqual(vm.jakeExcitement, 0.0)

        // Jump to 100% volume with high intensity
        vm.velocityTracker.setInputIntensityForTesting(1.0)
        vm.update(volume: 1.0, isMuted: false, animated: true)

        // Tick display loop
        vm.tick(explicitDeltaTime: 0.1)
        XCTAssertGreaterThan(vm.jakeExcitement, 0.3)
        XCTAssertGreaterThanOrEqual(vm.jakeLeanX, 0.0)
    }

    @MainActor
    func testHoltPatienceDepletionOnSpam() {
        let vm = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        XCTAssertEqual(vm.holtPatience, 1.0)

        // Spam volume-up at 100%
        vm.update(volume: 1.0, isMuted: false, animated: true)
        vm.update(volume: 1.0, isMuted: false, animated: true)
        vm.update(volume: 1.0, isMuted: false, animated: true)

        XCTAssertLessThan(vm.holtPatience, 1.0, "Spamming at 100% must deplete Holt's patience")
        XCTAssertGreaterThan(vm.overflowCoolCount, 0, "Spamming at 100% must produce overflow COOLs")
    }

    @MainActor
    func testOverflowCoolStackingAtMaxVolume() {
        let vm = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        XCTAssertEqual(vm.overflowCoolCount, 0)

        // Trigger overflow by continuing to press Volume Up
        vm.update(volume: 1.0, isMuted: false, animated: true)
        XCTAssertEqual(vm.overflowCoolCount, 1)
        XCTAssertEqual(vm.overflowOffsetsX.count, VolumeHUDViewModel.maxOverflowSlots)

        vm.update(volume: 1.0, isMuted: false, animated: true)
        XCTAssertEqual(vm.overflowCoolCount, 2)
    }

    func testEasterEggControllerCooldowns() {
        let controller = EasterEggController()
        XCTAssertTrue(controller.canTrigger(.bingpot))

        controller.markTriggered(.bingpot)
        XCTAssertFalse(controller.canTrigger(.bingpot), "Must be on cooldown immediately after trigger")

        // Other Easter eggs remain unaffected
        XCTAssertTrue(controller.canTrigger(.noDoubt))
        XCTAssertTrue(controller.canTrigger(.cheddar))
    }

    @MainActor
    func testCheddarCameoTrigger() {
        let vm = VolumeHUDViewModel(volume: 0.5, isMuted: false)
        XCTAssertFalse(vm.cheddarActive)

        vm.triggerCheddarForTesting()
        XCTAssertTrue(vm.cheddarActive)
        XCTAssertEqual(vm.cheddarPositionX, 120.0)

        // Ticking moves Cheddar to the right
        vm.tick(explicitDeltaTime: 0.1)
        XCTAssertGreaterThan(vm.cheddarPositionX, 120.0)
    }

    func testIntensityModes() {
        XCTAssertEqual(IntensityMode.professional.maxOverflowSlots, 1)
        XCTAssertEqual(IntensityMode.noice.maxOverflowSlots, 3)
        XCTAssertEqual(IntensityMode.fullPeralta.maxOverflowSlots, 5)

        XCTAssertLessThan(IntensityMode.professional.jakeMotionMultiplier, IntensityMode.noice.jakeMotionMultiplier)
        XCTAssertGreaterThan(IntensityMode.fullPeralta.jakeMotionMultiplier, IntensityMode.noice.jakeMotionMultiplier)
    }

    // MARK: - Dual Scene Sessions

    @MainActor
    func testSceneModeLocksForEntireSession() {
        let vm = VolumeHUDViewModel(volume: 0.3, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)
        let firstSessionID = vm.session?.id

        vm.update(volume: 0.8, isMuted: false, inputAction: .volumeUp)
        vm.beginSession(sceneMode: .coolHolt)

        XCTAssertEqual(vm.currentSceneMode, .runToTerry)
        XCTAssertEqual(vm.session?.id, firstSessionID)

        vm.endSession()
        vm.beginSession(sceneMode: .coolHolt)
        XCTAssertEqual(vm.currentSceneMode, .coolHolt)
        XCTAssertNotEqual(vm.session?.id, firstSessionID)
        vm.endSession()
    }

    func testSceneSelectorGuaranteesOneHoltAndOneTerryPerPair() {
        let selector = HUDSceneSelector()
        let expectedModes = Set(HUDSceneMode.allCases)

        for _ in 0..<50 {
            let pair = Set([selector.next(), selector.next()])
            XCTAssertEqual(pair, expectedModes)
        }
    }

    func testSceneSelectorSupportsDeterministicOrdering() {
        let selector = HUDSceneSelector(shuffler: { Array($0.reversed()) })
        XCTAssertEqual(selector.next(), .runToTerry)
        XCTAssertEqual(selector.next(), .coolHolt)
        XCTAssertEqual(selector.next(), .runToTerry)
        XCTAssertEqual(selector.next(), .coolHolt)
    }

    @MainActor
    func testWindowControllerRerollsOnlyAfterTrueSessionEnd() {
        var modes: [HUDSceneMode] = [.runToTerry, .coolHolt]
        let controller = HUDWindowController(sceneModeProvider: { modes.removeFirst() })

        controller.show(volume: 0.4, isMuted: false, inputAction: .volumeUp)
        XCTAssertEqual(controller.activeSceneMode, .runToTerry)

        controller.show(volume: 0.5, isMuted: false, inputAction: .volumeUp)
        XCTAssertEqual(controller.activeSceneMode, .runToTerry)

        controller.hide()
        XCTAssertFalse(controller.isSessionActive)

        controller.show(volume: 0.6, isMuted: false, inputAction: .volumeUp)
        XCTAssertEqual(controller.activeSceneMode, .coolHolt)
        controller.hide()
    }

    @MainActor
    func testWindowControllerAutomaticallyEndsSessionAfterHoldAndFade() {
        let controller = HUDWindowController(sceneModeProvider: { .runToTerry })
        controller.show(volume: 0.5, isMuted: false, inputAction: .volumeUp)
        XCTAssertTrue(controller.isSessionActive)

        let expectation = XCTestExpectation(description: "Fade completion releases scene session")
        DispatchQueue.main.asyncAfter(
            deadline: .now() + HUDWindowController.holdDuration + HUDWindowController.fadeDuration + 0.20
        ) {
            XCTAssertFalse(controller.isSessionActive)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4.0)
    }

    func testHoldDurationAddsExactlyTwoSecondsWithoutChangingFade() {
        XCTAssertEqual(
            HUDWindowController.holdDuration,
            HUDWindowController.originalHoldDuration + 2.0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(HUDWindowController.fadeDuration, 0.22, accuracy: 0.000_001)
    }

    // MARK: - Jake Runs to Terry

    @MainActor
    func testRunSceneMovesContinuouslyTowardVolume() {
        let vm = VolumeHUDViewModel(volume: 0.2, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)
        vm.update(volume: 0.9, isMuted: false, inputAction: .volumeUp)

        let initialProgress = vm.runToTerryState.visualProgress
        for _ in 0..<12 {
            vm.tick(explicitDeltaTime: 0.01)
        }

        XCTAssertGreaterThan(vm.runToTerryState.visualProgress, initialProgress)
        XCTAssertLessThanOrEqual(vm.runToTerryState.visualProgress, 0.9)
        XCTAssertTrue(vm.runToTerryState.isMoving)
        XCTAssertGreaterThan(vm.runToTerryState.velocity, 0)
        vm.endSession()
    }

    @MainActor
    func testRunSceneCatchAndSeamlessRetreat() {
        let vm = VolumeHUDViewModel(volume: 0.9, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)
        vm.update(volume: 1.0, isMuted: false, inputAction: .volumeUp)

        for _ in 0..<32 {
            vm.tick(explicitDeltaTime: 0.01)
        }
        XCTAssertTrue(vm.runToTerryState.isCaught)
        XCTAssertEqual(vm.runToTerryState.visualProgress, 1.0, accuracy: 0.000_1)

        vm.update(volume: 0.75, isMuted: false, inputAction: .volumeDown)
        XCTAssertFalse(vm.runToTerryState.isCaught)
        let releasedProgress = vm.runToTerryState.visualProgress
        vm.tick(explicitDeltaTime: 0.02)
        XCTAssertLessThan(vm.runToTerryState.visualProgress, releasedProgress)
        XCTAssertEqual(vm.runToTerryState.direction, -1)
        vm.endSession()
    }

    @MainActor
    func testRunSceneRapidDirectionChangesDoNotResetPositionOrSession() {
        let vm = VolumeHUDViewModel(volume: 0.3, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)
        let sessionID = vm.session?.id

        vm.update(volume: 0.8, isMuted: false, inputAction: .volumeUp)
        for _ in 0..<5 { vm.tick(explicitDeltaTime: 0.01) }
        let afterIncrease = vm.runToTerryState.visualProgress

        vm.update(volume: 0.4, isMuted: false, inputAction: .volumeDown)
        vm.tick(explicitDeltaTime: 0.02)
        let afterDecrease = vm.runToTerryState.visualProgress
        XCTAssertLessThan(afterDecrease, afterIncrease)
        XCTAssertEqual(vm.runToTerryState.direction, -1)

        vm.update(volume: 0.7, isMuted: false, inputAction: .volumeUp)
        vm.tick(explicitDeltaTime: 0.02)
        XCTAssertGreaterThan(vm.runToTerryState.visualProgress, afterDecrease)
        XCTAssertEqual(vm.runToTerryState.direction, 1)
        XCTAssertEqual(vm.session?.id, sessionID)
        XCTAssertEqual(vm.currentSceneMode, .runToTerry)
        vm.endSession()
    }

    @MainActor
    func testRunSceneMuteAndHighVolumeRestoreConvergeQuickly() {
        let vm = VolumeHUDViewModel(volume: 0.8, isMuted: false)
        vm.beginSession(sceneMode: .runToTerry)

        vm.update(volume: 0.8, isMuted: true, inputAction: .muteToggle)
        for _ in 0..<20 { vm.tick(explicitDeltaTime: 0.01) }
        XCTAssertLessThan(vm.runToTerryState.visualProgress, 0.04)
        XCTAssertFalse(vm.runToTerryState.isCaught)

        vm.update(volume: 0.8, isMuted: false, inputAction: .muteToggle)
        for _ in 0..<30 { vm.tick(explicitDeltaTime: 0.01) }
        XCTAssertEqual(vm.runToTerryState.visualProgress, 0.8, accuracy: 0.01)
        vm.endSession()
    }

    @MainActor
    func testBoundaryPressesProduceModeSpecificFeedback() {
        let cool = VolumeHUDViewModel(volume: 0, isMuted: false)
        cool.beginSession(sceneMode: .coolHolt)
        cool.update(volume: 0, isMuted: false, inputAction: .volumeDown)
        XCTAssertNotNil(cool.jakeSpeech)
        XCTAssertGreaterThan(cool.hudPulseScale, 1)
        cool.endSession()

        let terry = VolumeHUDViewModel(volume: 1, isMuted: false)
        terry.beginSession(sceneMode: .runToTerry)
        terry.update(volume: 1, isMuted: false, inputAction: .volumeUp)
        XCTAssertTrue(terry.runToTerryState.isCaught)
        XCTAssertGreaterThan(terry.runToTerryState.catchScale, 1)
        terry.update(volume: 1, isMuted: false, inputAction: .volumeUp)
        XCTAssertNotNil(terry.runToTerryState.terrySpeech)
        terry.endSession()
    }

    @MainActor
    func testTerryAssetsExistAndRenderSnapshots() {
        for name in ["terry_standing", "jake_run_1", "jake_run_2", "terry_catch"] {
            XCTAssertNotNil(PixelAssetLoader.shared.image(named: name), "\(name).png must be loadable")
        }

        let midRun = VolumeHUDViewModel(volume: 0.65, isMuted: false)
        midRun.beginSession(sceneMode: .runToTerry)
        midRun.update(volume: 0.65, isMuted: false, animated: false, inputAction: .externalChange)
        renderViewToPNG(view: VolumeHUDView(viewModel: midRun), filename: "hud_preview_terry_65.png")
        midRun.endSession()

        let caught = VolumeHUDViewModel(volume: 1.0, isMuted: false)
        caught.beginSession(sceneMode: .runToTerry)
        caught.update(volume: 1.0, isMuted: false, animated: false, inputAction: .externalChange)
        renderViewToPNG(view: VolumeHUDView(viewModel: caught), filename: "hud_preview_terry_100.png")
        caught.endSession()
    }
}
