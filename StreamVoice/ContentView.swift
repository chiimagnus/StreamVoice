import SwiftUI

struct ContentView: View {
    @State private var inputText: String = "这是一个测试文本，用来测试 GPT-SoVITS 的语音合成效果。"
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = false
    @State private var showingFilePicker = false
    @State private var referenceAudioPath: String?
    @State private var referenceText: String = ""
    @State private var showAdvancedSettings = false
    
    // 合成参数
    @State private var params = GPTSovitsSynthesisParams()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("GPT-SoVITS 测试")
                    .font(.title)
                    .padding()
                
                // 添加参考音频选择按钮
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "music.note")
                        Text(referenceAudioPath == nil ? "选择参考音频" : "更换参考音频")
                    }
                    .frame(width: 150)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                if let path = referenceAudioPath {
                    Text("已选择音频：\(URL(fileURLWithPath: path).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading) {
                        Text("参考音频文本：")
                            .font(.caption)
                        TextEditor(text: $referenceText)
                            .frame(height: 60)
                            .padding(5)
                            .border(Color.gray, width: 1)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("要合成的文本：")
                        .font(.caption)
                    TextEditor(text: $inputText)
                        .frame(height: 100)
                        .padding(5)
                        .border(Color.gray, width: 1)
                }
                
                // 高级设置折叠面板
                DisclosureGroup("高级设置", isExpanded: $showAdvancedSettings) {
                    VStack(spacing: 15) {
                        // 文本切分设置
                        Group {
                            Text("文本切分设置")
                                .font(.headline)
                            
                            Picker("切分方法", selection: $params.textSplitMethod) {
                                ForEach(TextSplitMethod.allCases, id: \.self) { method in
                                    Text(method.description).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            HStack {
                                Text("批处理大小")
                                Slider(value: .init(
                                    get: { Double(params.batchSize) },
                                    set: { params.batchSize = Int($0) }
                                ), in: Double(ParamRanges.batchSize.lowerBound)...Double(ParamRanges.batchSize.upperBound))
                                Text("\(params.batchSize)")
                            }
                            
                            HStack {
                                Text("批处理阈值")
                                Slider(value: $params.batchThreshold, in: 0.1...1.0)
                                Text(String(format: "%.2f", params.batchThreshold))
                            }
                            
                            Toggle("分桶处理", isOn: $params.splitBucket)
                            
                            Toggle("流式输出", isOn: $params.streamingMode)
                                .help("启用流式输出可以更快开始播放，但可能会有轻微的延迟")
                        }
                        
                        // 推理参数设置
                        Group {
                            Text("推理参数设置")
                                .font(.headline)
                                .padding(.top)
                            
                            HStack {
                                Text("Top-K")
                                Slider(value: .init(
                                    get: { Double(params.topK) },
                                    set: { params.topK = Int($0) }
                                ), in: Double(ParamRanges.topK.lowerBound)...Double(ParamRanges.topK.upperBound))
                                Text("\(params.topK)")
                            }
                            
                            HStack {
                                Text("Top-P")
                                Slider(value: $params.topP, in: ParamRanges.topP.lowerBound...ParamRanges.topP.upperBound)
                                Text(String(format: "%.2f", params.topP))
                            }
                            
                            HStack {
                                Text("温度系数")
                                Slider(value: $params.temperature, in: ParamRanges.temperature.lowerBound...ParamRanges.temperature.upperBound)
                                Text(String(format: "%.2f", params.temperature))
                            }
                            
                            HStack {
                                Text("重复惩罚")
                                Slider(value: $params.repetitionPenalty, in: ParamRanges.repetitionPenalty.lowerBound...ParamRanges.repetitionPenalty.upperBound)
                                Text(String(format: "%.2f", params.repetitionPenalty))
                            }
                            
                            Toggle("并行推理", isOn: $params.parallelInfer)
                            
                            HStack {
                                Text("语速系数")
                                Slider(value: $params.speedFactor, in: ParamRanges.speedFactor.lowerBound...ParamRanges.speedFactor.upperBound)
                                Text(String(format: "%.2f", params.speedFactor))
                            }
                            
                            HStack {
                                Text("片段间隔")
                                Slider(value: $params.fragmentInterval, in: ParamRanges.fragmentInterval.lowerBound...ParamRanges.fragmentInterval.upperBound)
                                Text(String(format: "%.2f", params.fragmentInterval))
                            }
                        }
                    }
                    .padding()
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await synthesizeAndPlay()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            }
                            Text(isPlaying ? "停止" : "播放")
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || referenceAudioPath == nil || referenceText.isEmpty)
                    
                    Button(action: {
                        Task {
                            await GPTSovits.shared.clearCache()
                        }
                    }) {
                        Text("清除缓存")
                            .frame(width: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
            .padding()
        }
        .alert("错误", isPresented: $showError, actions: {
            Button("确定", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "未知错误")
        })
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    if file.startAccessingSecurityScopedResource() {
                        referenceAudioPath = file.path
                        file.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                errorMessage = "选择音频文件失败：\(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func synthesizeAndPlay() async {
        if isPlaying {
            await GPTSovits.shared.stop()
            isPlaying = false
            return
        }
        
        guard let refPath = referenceAudioPath else {
            errorMessage = "请先选择参考音频文件"
            showError = true
            return
        }
        
        if referenceText.isEmpty {
            errorMessage = "请输入参考音频的文本内容"
            showError = true
            return
        }
        
        isLoading = true
        do {
            if params.streamingMode {
                print("🔵 使用流式输出模式")
                // 使用流式输出
                let audioStream = try await GPTSovits.shared.synthesizeStream(
                    text: inputText,
                    referenceAudioPath: refPath,
                    promptText: referenceText,
                    params: params
                )
                
                print("🟢 开始播放音频流")
                try await GPTSovits.shared.playStream(audioStream)
                print("🟢 音频流播放完成")
            } else {
                print("🔵 使用普通输出模式")
                // 使用普通输出
                let audioData = try await GPTSovits.shared.synthesize(
                    text: inputText,
                    referenceAudioPath: refPath,
                    promptText: referenceText,
                    params: params
                )
                print("🟢 开始播放音频")
                try await GPTSovits.shared.play(audioData)
                print("🟢 音频播放完成")
            }
            isPlaying = true
        } catch {
            print("🔴 播放失败：\(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            isPlaying = false
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}

