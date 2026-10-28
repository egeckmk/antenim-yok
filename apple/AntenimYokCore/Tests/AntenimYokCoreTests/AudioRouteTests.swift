import Testing
@testable import AntenimYokCore

@Suite struct AudioRoutePolicyTests {
    @Test(arguments: [AudioOutputKind.headphones, .bluetooth, .airPlay, .car])
    func unpluggingPrivateOutputStops(kind: AudioOutputKind) {
        #expect(AudioRoutePolicy.shouldStop(reason: .oldDeviceUnavailable, previousOutputs: [kind]))
    }

    @Test(arguments: [AudioOutputKind.builtInSpeaker, .builtInReceiver, .other])
    func losingBuiltInOrUnknownOutputDoesNotStop(kind: AudioOutputKind) {
        #expect(!AudioRoutePolicy.shouldStop(reason: .oldDeviceUnavailable, previousOutputs: [kind]))
    }

    @Test(arguments: [AudioRouteChangeReason.newDeviceAvailable, .categoryChange, .override, .wakeFromSleep,
                      .noSuitableRouteForCategory, .routeConfigurationChange, .unknown])
    func otherReasonsNeverStop(reason: AudioRouteChangeReason) {
        #expect(!AudioRoutePolicy.shouldStop(reason: reason, previousOutputs: [.headphones, .bluetooth]))
    }

    @Test func noPreviousOutputsDoesNotStop() {
        #expect(!AudioRoutePolicy.shouldStop(reason: .oldDeviceUnavailable, previousOutputs: []))
    }

    @Test func anyPrivateOutputAmongSeveralStops() {
        #expect(AudioRoutePolicy.shouldStop(reason: .oldDeviceUnavailable, previousOutputs: [.builtInSpeaker, .bluetooth]))
    }
}

@Suite struct AudioInterruptionPolicyTests {
    @Test func beganWaits() {
        #expect(AudioInterruptionPolicy.action(for: .began) == .waitForEnd)
    }

    @Test func endedWithResumeResumes() {
        #expect(AudioInterruptionPolicy.action(for: .ended(shouldResume: true)) == .resume)
    }

    @Test func endedWithoutResumeStops() {
        #expect(AudioInterruptionPolicy.action(for: .ended(shouldResume: false)) == .stop)
    }
}
