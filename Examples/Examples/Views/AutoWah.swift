import AudioKit
import AVFoundation
import SwiftUI

struct AutoWahData {
    var isPlaying: Bool = false
    var wah: AUValue = 0.0
    var mix: AUValue = 1.0
    var amplitude: AUValue = 0.1
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class AutoWahConductor: ObservableObject {
    let engine = AKEngine()
    let player = AKPlayer()
    let autowah: AKAutoWah
    let dryWetMixer: AKDryWetMixer
    let playerPlot: AKNodeOutputPlot
    let autowahPlot: AKNodeOutputPlot
    let mixPlot: AKNodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        autowah = AKAutoWah(player)
        dryWetMixer = AKDryWetMixer(player, autowah)
        playerPlot = AKNodeOutputPlot(player)
        autowahPlot = AKNodeOutputPlot(autowah)
        mixPlot = AKNodeOutputPlot(dryWetMixer)
        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        autowahPlot.plotType = .rolling
        autowahPlot.color = .blue
        autowahPlot.shouldFill = true
        autowahPlot.shouldMirror = true
        autowahPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = AutoWahData() {
        didSet {
            if data.isPlaying {
                player.play()
                autowah.$wah.ramp(to: data.wah, duration: data.rampDuration)
                autowah.$mix.ramp(to: data.mix, duration: data.rampDuration)
                autowah.$amplitude.ramp(to: data.amplitude, duration: data.rampDuration)
                dryWetMixer.balance = data.balance

            } else {
                player.pause()
            }

        }
    }

    func start() {
        playerPlot.start()
        autowahPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            AKLog(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct AutoWahView: View {
    @ObservedObject var conductor = AutoWahConductor()

    var body: some View {
        VStack {
            Text(self.conductor.data.isPlaying ? "STOP" : "START").onTapGesture {
                self.conductor.data.isPlaying.toggle()
            }
            ParameterSlider(text: "Wah Amount",
                            parameter: self.$conductor.data.wah,
                            range: 0.0...1.0).padding(5)
            ParameterSlider(text: "Overall level",
                            parameter: self.$conductor.data.amplitude,
                            range: 0.0...1.0).padding(5)
            ParameterSlider(text: "Ramp Duration",
                            parameter: self.$conductor.data.rampDuration,
                            range: 0...4,
                            format: "%0.2f").padding(5)
            ParameterSlider(text: "Balance",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            format: "%0.2f").padding(5)
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.playerPlot).clipped()
                Text("Input")
            }
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.autowahPlot).clipped()
                Text("AKAutoWahed Signal")
            }
            ZStack(alignment:.topLeading) {
                PlotView(view: conductor.mixPlot).clipped()
                Text("Mixed Output")
            }
        }
        .padding()
        .navigationBarTitle(Text("Auto Wah"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}