import SwiftUI
import Combine

// MARK: - API Key

private let kDeepSeekAPIKey = "sk-25ef4ad971d641a49bd7c3af49a936f8"

// MARK: - iTunes Track Model

struct SpotifyTrack: Identifiable {
    let id: String
    let name: String
    let artist: String
    let spotifyUrl: String  // actually an Apple Music / iTunes URL
}

// MARK: - iTunes Search Service
// Uses Apple's public iTunes Search API — no API key, no Premium required.

actor SpotifyService {
    static let shared = SpotifyService()
    private init() {}

    func search(bpm: Int, energy: Int, genreTags: String, slot: Int) async throws -> [SpotifyTrack] {
        let tags = genreTags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Rotate primary tag per slot for variety
        let primaryTag = tags.isEmpty ? "electronic" : tags[(slot - 1) % tags.count]
        // Fallback to first word if multi-word (e.g. "liquid" from "liquid drum and bass")
        let fallbackTag = primaryTag.split(separator: " ").prefix(2).joined(separator: "+")
        let queries = [primaryTag, fallbackTag, "electronic music"]

        for query in queries {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            // offset varies by slot so each slot gets different results
            let offset = ((slot - 1) % 4) * 5
            guard let url = URL(string:
                "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=8&offset=\(offset)"
            ) else { continue }

            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[iTunes] HTTP \(http.statusCode) for query '\(query)'")
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                print("[iTunes] Parse failed for query '\(query)'")
                continue
            }

            let tracks = results.compactMap { r -> SpotifyTrack? in
                guard let trackId   = r["trackId"]   as? Int,
                      let trackName = r["trackName"] as? String,
                      let artist    = r["artistName"] as? String,
                      let trackUrl  = r["trackViewUrl"] as? String else { return nil }
                return SpotifyTrack(id: "\(trackId)", name: trackName, artist: artist, spotifyUrl: trackUrl)
            }.prefix(3).map { $0 }

            print("[iTunes] slot \(slot) query '\(query)' → \(tracks.count) tracks")
            if !tracks.isEmpty { return tracks }
        }
        return []
    }
}

// MARK: - Music Genre Presets

struct MusicGenre: Identifiable, Hashable {
    let id: String
    let name: String
    let nameCN: String
    let tags: String
    let bpmMin: Double
    let bpmMax: Double

    static let all: [MusicGenre] = [
        .init(id: "custom",      name: "Custom",                nameCN: "自定义",           tags: "",                                          bpmMin: 120, bpmMax: 140),
        .init(id: "liquidDnB",   name: "Liquid DnB",            nameCN: "Liquid D&B",      tags: "liquid drum and bass, soulful, atmospheric", bpmMin: 170, bpmMax: 176),
        .init(id: "neurofunk",   name: "Neurofunk",             nameCN: "神经放克",         tags: "neurofunk, dark, technical, bass",           bpmMin: 172, bpmMax: 178),
        .init(id: "techno",      name: "Techno",                nameCN: "科技舞曲",         tags: "techno, driving, dark, industrial",          bpmMin: 130, bpmMax: 145),
        .init(id: "minTechno",   name: "Minimal Techno",        nameCN: "极简科技",         tags: "minimal techno, hypnotic, repetitive",       bpmMin: 128, bpmMax: 138),
        .init(id: "deepHouse",   name: "Deep House",            nameCN: "深度浩室",         tags: "deep house, soulful, warm, groovy",          bpmMin: 118, bpmMax: 126),
        .init(id: "techHouse",   name: "Tech House",            nameCN: "科技浩室",         tags: "tech house, groovy, punchy, underground",    bpmMin: 124, bpmMax: 132),
        .init(id: "progHouse",   name: "Progressive House",     nameCN: "进行浩室",         tags: "progressive house, melodic, euphoric",       bpmMin: 125, bpmMax: 132),
        .init(id: "melodicTech", name: "Melodic Techno",        nameCN: "旋律科技",         tags: "melodic techno, dark, atmospheric, hypnotic",bpmMin: 130, bpmMax: 140),
        .init(id: "trance",      name: "Trance",                nameCN: "迷幻舞曲",         tags: "trance, euphoric, uplifting, melodic",       bpmMin: 136, bpmMax: 145),
        .init(id: "dubstep",     name: "Dubstep",               nameCN: "电子贝斯",         tags: "dubstep, heavy, bass, aggressive",           bpmMin: 138, bpmMax: 145),
        .init(id: "jungle",      name: "Jungle",                nameCN: "丛林",             tags: "jungle, breakbeat, ragga, raw",              bpmMin: 160, bpmMax: 170),
        .init(id: "ambient",     name: "Ambient",               nameCN: "氛围音乐",         tags: "ambient, atmospheric, cinematic, slow",      bpmMin: 60,  bpmMax: 100),
        .init(id: "afrohouse",   name: "Afro House",            nameCN: "非洲浩室",         tags: "afro house, tribal, percussive, warm",       bpmMin: 120, bpmMax: 128),
        .init(id: "hardtechno",  name: "Hard Techno",           nameCN: "硬核科技",         tags: "hard techno, aggressive, industrial, peak",  bpmMin: 140, bpmMax: 155),
    ]
}

// MARK: - Models

struct TrackSlot: Identifiable, Codable {
    let id = UUID()
    var slot: Int
    var bpm: Int
    var energy: Int
    var transition: String
    var vibe: String

    enum CodingKeys: String, CodingKey {
        case slot, bpm, energy, transition, vibe
    }
}

struct SetPlan: Codable {
    var tracks: [TrackSlot]
    var djNotes: String
}

enum EventType: String, CaseIterable, Identifiable {
    case warmUp = "warm-up"
    case peak = "peak"
    case closing = "closing"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .warmUp: return "Warm-Up"
        case .peak: return "Peak"
        case .closing: return "Closing"
        }
    }
    var labelCN: String {
        switch self {
        case .warmUp: return "热场"
        case .peak: return "高潮"
        case .closing: return "收尾"
        }
    }
    var icon: String {
        switch self {
        case .warmUp: return "sunrise"
        case .peak: return "flame"
        case .closing: return "moon.stars"
        }
    }
}

// MARK: - ViewModel

@MainActor
class DJSetViewModel: ObservableObject {
    @Published var isChinese: Bool = false
    @Published var selectedGenre: MusicGenre = MusicGenre.all[0]
    @Published var eventType: EventType = .peak
    @Published var duration: Double = 60
    @Published var bpmMin: Double = 128
    @Published var bpmMax: Double = 140
    @Published var genreTags: String = "techno, melodic, dark, hypnotic"

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var setPlan: SetPlan? = nil
    @Published var spotifyTracks: [Int: [SpotifyTrack]] = [:]
    @Published var isLoadingSpotify: Bool = false

    var spotifyConfigured: Bool { true }  // iTunes Search API needs no credentials

    func applyGenre(_ genre: MusicGenre) {
        selectedGenre = genre
        if genre.id != "custom" {
            genreTags = genre.tags
            bpmMin = genre.bpmMin
            bpmMax = genre.bpmMax
        }
    }

    func generate() async {
        guard bpmMin <= bpmMax else {
            errorMessage = isChinese ? "BPM 最小值不能大于最大值。" : "BPM min cannot be greater than BPM max."
            return
        }

        isLoading = true
        errorMessage = nil
        setPlan = nil
        spotifyTracks = [:]

        let trackCount = max(5, Int((duration / 8).rounded()))
        let arcHint: String
        switch eventType {
        case .warmUp: arcHint = "start low energy and build gradually, begin at lower BPM end"
        case .peak: arcHint = "maintain high energy throughout with dynamic peaks and drops"
        case .closing: arcHint = "start high then gradually wind down, reduce BPM toward the end"
        }

        let promptText = """
You are an expert DJ set planner. Generate a detailed DJ set plan for:

Event Type: \(eventType.rawValue)
Set Duration: \(Int(duration)) minutes
BPM Range: \(Int(bpmMin))–\(Int(bpmMax)) BPM
Genre/Vibe: \(genreTags)
Number of track slots: \(trackCount)

\(isChinese ? "请用中文回复所有文字内容（vibe 和 djNotes 字段）。" : "Respond in English.")
Respond ONLY with valid JSON, no markdown, no extra text:
{
  "tracks": [
    {
      "slot": 1,
      "bpm": 128,
      "energy": 5,
      "transition": "blend",
      "vibe": "Brief vibe/mood description"
    }
  ],
  "djNotes": "A paragraph summarizing the arc of the set."
}

Rules:
- "energy" is 1–10 integer
- "transition" is one of: blend, cut, fx drop
- BPM values must stay within \(Int(bpmMin))–\(Int(bpmMax))
- For "\(eventType.rawValue)" sets: \(arcHint)
- Keep "vibe" notes concise (1–2 sentences)
"""

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "max_tokens": 1000,
            "messages": [["role": "user", "content": promptText]]
        ]

        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = isChinese ? "请求构建失败。" : "Failed to build request."
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(kDeepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errObj = errJson["error"] as? [String: Any],
                   let msg = errObj["message"] as? String {
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: msg])
                }
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode)"])
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Unexpected API response format."])
            }

            // Parse JSON from text (strip any markdown fences)
            let jsonString = extractJSON(from: text)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not encode response."])
            }

            let decoder = JSONDecoder()
            let plan = try decoder.decode(SetPlan.self, from: jsonData)
            setPlan = plan

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false

        // Fetch track recommendations via iTunes Search API concurrently for each slot
        if spotifyConfigured, let plan = setPlan {
            isLoadingSpotify = true
            let tags = genreTags
            var results: [Int: [SpotifyTrack]] = [:]
            await withTaskGroup(of: (Int, [SpotifyTrack]).self) { group in
                for t in plan.tracks {
                    let slot = t.slot; let bpm = t.bpm; let energy = t.energy
                    group.addTask {
                        let tracks = (try? await SpotifyService.shared.search(
                            bpm: bpm, energy: energy, genreTags: tags, slot: slot
                        )) ?? []
                        return (slot, tracks)
                    }
                }
                for await (slot, tracks) in group { results[slot] = tracks }
            }
            spotifyTracks = results
            isLoadingSpotify = false
        }
    }

    private func extractJSON(from text: String) -> String {
        // Strip markdown code fences if present
        var s = text
        if let start = s.range(of: "{"), let end = s.range(of: "}", options: .backwards) {
            s = String(s[start.lowerBound...end.lowerBound])
        }
        return s
    }

    func plainTextExport() -> String {
        guard let plan = setPlan else { return "" }
        var lines = [String]()
        lines.append("DJ SET PLAN")
        lines.append(String(repeating: "=", count: 40))
        lines.append("Event: \(eventType.label) | Duration: \(Int(duration)) min | BPM: \(Int(bpmMin))–\(Int(bpmMax))")
        lines.append("Vibe: \(genreTags)")
        lines.append("")
        lines.append("TRACKLIST")
        lines.append(String(repeating: "-", count: 40))
        for t in plan.tracks {
            lines.append("[\(t.slot)] \(t.bpm) BPM | Energy: \(t.energy)/10 | Transition: \(t.transition)")
            lines.append("    \(t.vibe)")
            if let recs = spotifyTracks[t.slot], !recs.isEmpty {
                lines.append(isChinese ? "    推荐曲目:" : "    Recommended Tracks:")
                for rec in recs {
                    lines.append("    • \(rec.name) — \(rec.artist)")
                }
            }
            lines.append("")
        }
        lines.append("DJ NOTES")
        lines.append(String(repeating: "-", count: 40))
        lines.append(plan.djNotes)
        return lines.joined(separator: "\n")
    }
}

// MARK: - Colors / Theme

extension Color {
    static let djBg = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let djSurface = Color(red: 0.07, green: 0.07, blue: 0.10)
    static let djBorder = Color(red: 0.17, green: 0.17, blue: 0.25)
    static let djNeon = Color(red: 0.00, green: 0.96, blue: 1.00)
    static let djNeon2 = Color(red: 0.75, green: 0.00, blue: 1.00)
    static let djNeon3 = Color(red: 1.00, green: 0.00, blue: 0.43)
    static let djMuted = Color(red: 0.44, green: 0.44, blue: 0.63)
}

// MARK: - Main App Entry

@main
struct DJSetPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = DJSetViewModel()
    @State private var showShareSheet = false
    @State private var shareText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.djBg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Header strip
                        headerView

                        // Config Panel
                        configPanel

                        // Error
                        if let err = vm.errorMessage {
                            errorCard(err)
                        }

                        // Loading
                        if vm.isLoading {
                            loadingCard
                        }

                        // Results
                        if let plan = vm.setPlan {
                            resultsSection(plan)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
        }
    }

    // MARK: Header
    var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                // Language toggle
                Button {
                    vm.isChinese.toggle()
                } label: {
                    Text(vm.isChinese ? "EN" : "中")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.djNeon)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.djNeon, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            Text("♫ DJ SET PLANNER")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.djNeon, .djNeon2],
                    startPoint: .leading, endPoint: .trailing
                ))
            Text(vm.isChinese ? "由DEEPSEEK驱动" : "POWERED BY DEEPSEEK")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.djMuted)
                .kerning(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(LinearGradient(
                    colors: [.clear, .djNeon, .djNeon2, .clear],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
    }

    // MARK: Config Panel
    var configPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel(vm.isChinese ? "▶ 演出配置" : "▶ SET CONFIGURATION", color: .djNeon)

            // Event Type Picker
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(vm.isChinese ? "演出类型" : "EVENT TYPE")
                HStack(spacing: 8) {
                    ForEach(EventType.allCases) { type in
                        eventTypeButton(type)
                    }
                }
            }

            // Duration
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(vm.isChinese ? "演出时长: \(Int(vm.duration)) 分钟" : "SET DURATION: \(Int(vm.duration)) MIN")
                Slider(value: $vm.duration, in: 15...360, step: 5)
                    .tint(.djNeon)
            }

            // BPM Range
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(vm.isChinese ? "BPM 范围: \(Int(vm.bpmMin)) – \(Int(vm.bpmMax))" : "BPM RANGE: \(Int(vm.bpmMin)) – \(Int(vm.bpmMax))")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.isChinese ? "最低" : "MIN").font(.system(size: 9, weight: .bold)).foregroundColor(.djMuted).kerning(1)
                        Slider(value: $vm.bpmMin, in: 60...200, step: 1)
                            .tint(.djNeon)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.isChinese ? "最高" : "MAX").font(.system(size: 9, weight: .bold)).foregroundColor(.djMuted).kerning(1)
                        Slider(value: $vm.bpmMax, in: 60...200, step: 1)
                            .tint(.djNeon2)
                    }
                }
            }

            // Genre Tags
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(vm.isChinese ? "曲风类型" : "MUSIC GENRE")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MusicGenre.all) { genre in
                            let isSelected = vm.selectedGenre.id == genre.id
                            Button { vm.applyGenre(genre) } label: {
                                Text(vm.isChinese ? genre.nameCN : genre.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isSelected ? .djNeon : .djMuted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.djNeon.opacity(0.12) : Color.djBg)
                                    .overlay(
                                        Capsule().stroke(isSelected ? Color.djNeon : Color.djBorder, lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Free-text vibe tags
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(vm.isChinese ? "风格 / 氛围标签" : "VIBE TAGS")
                TextField(vm.isChinese ? "例如：科技、旋律浩室、黑暗" : "e.g. techno, melodic house, dark", text: $vm.genreTags)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color.djBg)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.djBorder, lineWidth: 1)
                    )
                Text(vm.isChinese ? "用逗号分隔" : "Comma-separated tags")
                    .font(.system(size: 10))
                    .foregroundColor(.djMuted)
            }

            // Generate Button
            Button {
                Task { await vm.generate() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text(vm.isChinese ? "生成演出计划" : "GENERATE SET PLAN")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .kerning(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red: 0, green: 0.78, blue: 1), .djNeon2],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(vm.isLoading)
            .opacity(vm.isLoading ? 0.5 : 1)

        }
        .padding(20)
        .background(Color.djSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.djBorder, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            LinearGradient(colors: [.djNeon2, .djNeon, .djNeon3], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
                .cornerRadius(14, corners: [.topLeft, .topRight])
        }
        .cornerRadius(14)
    }

    func eventTypeButton(_ type: EventType) -> some View {
        let isSelected = vm.eventType == type
        return Button {
            vm.eventType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))
                Text(vm.isChinese ? type.labelCN : type.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Color.djNeon.opacity(0.18) : Color.djBg)
            .foregroundColor(isSelected ? .djNeon : .djMuted)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.djNeon : Color.djBorder, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Loading
    var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.djNeon)
                .scaleEffect(1.3)
            Text(vm.isChinese ? "正在生成套组计划..." : "GENERATING YOUR SET PLAN...")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.djMuted)
                .kerning(2)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.djSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.djBorder, lineWidth: 1)
        )
    }

    // MARK: Error
    func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.djNeon3)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 1, green: 0.43, blue: 0.63))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.djNeon3.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.djNeon3.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: Results
    func resultsSection(_ plan: SetPlan) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(vm.isChinese ? "♫ 曲目计划" : "♫ TRACKLIST PLAN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.djNeon2)
                    .kerning(2)
                Spacer()
                Button {
                    shareText = vm.plainTextExport()
                    showShareSheet = true
                } label: {
                    Label(vm.isChinese ? "导出" : "Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.djMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.djBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            ForEach(plan.tracks) { track in
                TrackCardView(track: track, isChinese: vm.isChinese,
                              spotifyTracks: vm.spotifyTracks[track.slot] ?? [],
                              isLoadingSpotify: vm.isLoadingSpotify)
            }

            DJNotesView(notes: plan.djNotes, isChinese: vm.isChinese)
        }
    }

    // MARK: Helpers
    func sectionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .kerning(2)
    }

    func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.djMuted)
            .kerning(1.5)
    }
}

// MARK: - Track Card View

struct TrackCardView: View {
    let track: TrackSlot
    let isChinese: Bool
    let spotifyTracks: [SpotifyTrack]
    let isLoadingSpotify: Bool

    var energyColor: Color {
        if track.energy <= 3 { return Color(red: 0, green: 0.79, blue: 0.65) }
        if track.energy <= 6 { return Color(red: 0.98, green: 0.78, blue: 0.31) }
        return Color.djNeon3
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Slot number
            ZStack {
                Circle()
                    .stroke(Color.djBorder, lineWidth: 1)
                    .frame(width: 40, height: 40)
                Text("\(track.slot)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.djNeon)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Badges row
                HStack(spacing: 6) {
                    badge("\(track.bpm) BPM", fg: .djNeon,
                          bg: Color.djNeon.opacity(0.12),
                          border: Color.djNeon.opacity(0.25))
                    badge(track.transition.uppercased(), fg: Color(red: 0.85, green: 0.40, blue: 1),
                          bg: Color.djNeon2.opacity(0.12),
                          border: Color.djNeon2.opacity(0.25))
                    Spacer()
                }

                // Energy bar
                HStack(spacing: 6) {
                    Text(isChinese ? "能量" : "ENERGY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.djMuted)
                        .kerning(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.djBorder)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(energyColor)
                                .frame(width: geo.size.width * CGFloat(track.energy) / 10, height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(track.energy)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(energyColor)
                        .frame(minWidth: 16, alignment: .trailing)
                }

                // Vibe
                Text(track.vibe)
                    .font(.system(size: 13))
                    .foregroundColor(.djMuted)
                    .fixedSize(horizontal: false, vertical: true)

                // Spotify recommendations
                if isLoadingSpotify && spotifyTracks.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7).tint(.djNeon)
                        Text(isChinese ? "正在获取推荐曲目..." : "Fetching recommendations...")
                            .font(.system(size: 10))
                            .foregroundColor(.djMuted)
                    }
                } else if !spotifyTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isChinese ? "▶ 推荐曲目" : "▶ RECOMMENDED TRACKS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.djNeon)
                            .kerning(1)
                        ForEach(spotifyTracks) { rec in
                            Link(destination: URL(string: rec.spotifyUrl)!) {
                                HStack(spacing: 8) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 10))
                                        .foregroundColor(.djNeon)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(rec.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(rec.artist)
                                            .font(.system(size: 11))
                                            .foregroundColor(.djMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.djMuted)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            } // close inner VStack
        } // close HStack
        .padding(14)
        .background(Color(red: 0.086, green: 0.086, blue: 0.122))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.djBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    func badge(_ text: String, fg: Color, bg: Color, border: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .overlay(
                Capsule().stroke(border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

// MARK: - DJ Notes View

struct DJNotesView: View {
    let notes: String
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "◆ DJ 备注 — 演出走向" : "◆ DJ NOTES — SET ARC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.djNeon3)
                .kerning(2)
            Text(notes)
                .font(.system(size: 14))
                .foregroundColor(.djMuted)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.djSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.djBorder, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            LinearGradient(colors: [.djNeon3, .djNeon2], startPoint: .leading, endPoint: .trailing)
                .frame(height: 2)
                .cornerRadius(14, corners: [.topLeft, .topRight])
        }
        .cornerRadius(14)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
