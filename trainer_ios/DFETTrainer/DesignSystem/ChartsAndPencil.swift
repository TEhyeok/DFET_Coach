import Charts
import PencilKit
import SwiftUI

private struct ChartSeriesPoint: Identifiable {
  let session: Int
  let label: String
  let value: Double

  var id: Int { session }
}

private func weeklyPoints(from values: [Double]) -> [ChartSeriesPoint] {
  let labels = recentWeeklyLabels(count: values.count)
  return values.enumerated().map { index, value in
    ChartSeriesPoint(session: index + 1, label: labels[index], value: value)
  }
}

private func recentWeeklyLabels(count: Int) -> [String] {
  let previewLabels = ["3/18", "3/25", "4/1", "4/8", "4/15", "4/22", "4/29", "5/6"]
  if count <= previewLabels.count {
    return Array(previewLabels.suffix(count))
  }
  return (1...count).map { "\($0)주" }
}

struct PainCompletionChart: View {
  let painPoints: [Double]
  let completionPoints: [Double]
  var secondaryTitle: String = "기록 완료율"

  private var painData: [ChartSeriesPoint] {
    weeklyPoints(from: painPoints)
  }

  private var completionData: [ChartSeriesPoint] {
    weeklyPoints(from: completionPoints)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      compactHeader(title: "통증 변화", value: painCompactSummary, color: TrainerColor.deepBlue)
      Chart {
        ForEach(painData) { point in
          AreaMark(
            x: .value("주", point.session),
            yStart: .value("기준", 0),
            yEnd: .value("통증", point.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(
            LinearGradient(
              colors: [TrainerColor.blue.opacity(0.20), TrainerColor.blue.opacity(0.025)],
              startPoint: .top,
              endPoint: .bottom
            )
          )

          LineMark(
            x: .value("주", point.session),
            y: .value("통증", point.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(TrainerColor.deepBlue)
          .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

          PointMark(
            x: .value("주", point.session),
            y: .value("통증", point.value)
          )
          .symbolSize(point.session == painData.last?.session ? 58 : 26)
          .foregroundStyle(point.session == painData.last?.session ? TrainerColor.deepBlue : TrainerColor.blue.opacity(0.78))
        }

        RuleMark(y: .value("주의 기준", 6))
          .foregroundStyle(TrainerColor.purple.opacity(0.38))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
      }
      .chartYScale(domain: 0...10)
      .chartYAxis {
        AxisMarks(position: .leading, values: [0, 5, 10]) { value in
          AxisGridLine().foregroundStyle(TrainerColor.border)
          AxisValueLabel {
            if let intValue = value.as(Int.self) {
              Text("\(intValue)")
                .font(TrainerFont.label(10, weight: .semibold))
                .foregroundStyle(TrainerColor.tertiaryText)
            }
          }
        }
      }
      .chartXAxis {
        AxisMarks(values: painData.map(\.session)) { value in
          AxisGridLine().foregroundStyle(.clear)
          AxisValueLabel {
            if let session = value.as(Int.self),
               let label = painData.first(where: { $0.session == session })?.label {
              Text(label)
                .font(TrainerFont.label(10, weight: .semibold))
                .foregroundStyle(TrainerColor.tertiaryText)
            }
          }
        }
      }
      .chartPlotStyle { plotArea in
        plotArea
          .background(TrainerColor.quietFill.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .frame(height: 126)

      compactHeader(title: secondaryTitle, value: completionCompactSummary, color: TrainerColor.blue)
      Chart {
        ForEach(completionData) { point in
          BarMark(
            x: .value("주", point.label),
            yStart: .value("기준", 0),
            yEnd: .value("완료율", point.value),
            width: .ratio(0.58)
          )
          .cornerRadius(7)
          .foregroundStyle(
            LinearGradient(
              colors: [TrainerColor.blue.opacity(0.95), TrainerColor.purple.opacity(0.64)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .opacity(point.value >= 80 ? 0.96 : 0.68)
        }

        RuleMark(y: .value("목표", 80))
          .foregroundStyle(TrainerColor.deepBlue.opacity(0.32))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
      }
      .chartYScale(domain: 0...100)
      .chartYAxis {
        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
          AxisGridLine().foregroundStyle(TrainerColor.border)
          AxisValueLabel {
            if let intValue = value.as(Int.self) {
              Text("\(intValue)%")
                .font(TrainerFont.label(10, weight: .semibold))
                .foregroundStyle(TrainerColor.tertiaryText)
            }
          }
        }
      }
      .chartXAxis {
        AxisMarks(values: completionData.map(\.label)) { value in
          AxisGridLine().foregroundStyle(.clear)
          AxisValueLabel {
            if let label = value.as(String.self) {
              Text(label)
                .font(TrainerFont.label(10, weight: .semibold))
                .foregroundStyle(TrainerColor.tertiaryText)
            }
          }
        }
      }
      .chartPlotStyle { plotArea in
        plotArea
          .background(TrainerColor.quietFill.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .frame(height: 104)
    }
  }

  private var painCompactSummary: String {
    guard let first = painPoints.first, let last = painPoints.last else { return "-" }
    let delta = last - first
    return delta <= 0 ? String(format: "%.1f · %.1f↓", last, abs(delta)) : String(format: "%.1f · %.1f↑", last, delta)
  }

  private var completionCompactSummary: String {
    guard let first = completionPoints.first, let last = completionPoints.last else { return "-" }
    let delta = Int(last - first)
    return delta >= 0 ? "\(Int(last))% · +\(delta)" : "\(Int(last))% · \(delta)"
  }

  private func compactHeader(title: String, value: String, color: Color) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(TrainerFont.label(14, weight: .bold))
        .foregroundStyle(TrainerColor.primaryText)
      Spacer()
      Text(value)
        .font(TrainerFont.label(13, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
    }
  }
}

struct ClinicalReportChart: View {
  let painPoints: [Double]
  let completionPoints: [Double]

  private var painData: [ChartSeriesPoint] {
    weeklyPoints(from: painPoints)
  }

  private var completionData: [ChartSeriesPoint] {
    weeklyPoints(from: completionPoints)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      chartBlock(
        title: "통증 변화",
        value: painSummary,
        caption: "0은 통증 없음, 10은 최대 통증",
        color: TrainerColor.deepBlue
      ) {
        Chart {
          ForEach(painData) { point in
            AreaMark(
              x: .value("주", point.session),
              yStart: .value("기준", 0),
              yEnd: .value("통증", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
              LinearGradient(
                colors: [TrainerColor.blue.opacity(0.24), TrainerColor.blue.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
              )
            )

            LineMark(
              x: .value("주", point.session),
              y: .value("통증", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(TrainerColor.deepBlue)
            .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

            PointMark(
              x: .value("주", point.session),
              y: .value("통증", point.value)
            )
            .symbolSize(point.session == painData.last?.session ? 72 : 34)
            .foregroundStyle(point.session == painData.last?.session ? TrainerColor.deepBlue : TrainerColor.blue)
          }

          RuleMark(y: .value("주의 기준", 6))
            .foregroundStyle(TrainerColor.purple.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .annotation(position: .top, alignment: .leading) {
              Text("주의 6")
                .font(TrainerFont.label(11, weight: .bold))
                .foregroundStyle(TrainerColor.purple)
            }

          RuleMark(y: .value("관리 목표", 3))
            .foregroundStyle(TrainerColor.blue.opacity(0.24))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 6]))
            .annotation(position: .bottom, alignment: .leading) {
              Text("목표 3")
                .font(TrainerFont.label(11, weight: .bold))
                .foregroundStyle(TrainerColor.blue)
            }
        }
        .chartYScale(domain: 0...10)
        .chartYAxis {
          AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) { value in
            AxisGridLine().foregroundStyle(TrainerColor.border)
            AxisValueLabel {
              if let intValue = value.as(Int.self) {
                Text("\(intValue)")
                  .font(TrainerFont.label(11, weight: .semibold))
                  .foregroundStyle(TrainerColor.secondaryText)
              }
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: painData.map(\.session)) { value in
            AxisGridLine().foregroundStyle(.clear)
            AxisValueLabel {
              if let session = value.as(Int.self),
                 let label = painData.first(where: { $0.session == session })?.label {
                Text(label)
                  .font(TrainerFont.label(10, weight: .semibold))
                  .foregroundStyle(TrainerColor.tertiaryText)
              }
            }
          }
        }
      }

      chartBlock(
        title: "SOAP 완료율",
        value: completionSummary,
        caption: "세션 후 공유 가능한 기록 정리 비율",
        color: TrainerColor.blue
      ) {
        Chart {
          ForEach(completionData) { point in
            BarMark(
              x: .value("주", point.label),
              yStart: .value("기준", 0),
              yEnd: .value("완료율", point.value),
              width: .ratio(0.62)
            )
            .cornerRadius(7)
            .foregroundStyle(
              LinearGradient(
                colors: [TrainerColor.blue, TrainerColor.purple.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .opacity(point.value >= 80 ? 0.96 : 0.70)
          }

          RuleMark(y: .value("목표", 80))
            .foregroundStyle(TrainerColor.deepBlue.opacity(0.36))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .annotation(position: .top, alignment: .leading) {
              Text("목표 80%")
                .font(TrainerFont.label(11, weight: .bold))
                .foregroundStyle(TrainerColor.deepBlue)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
          AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
            AxisGridLine().foregroundStyle(TrainerColor.border)
            AxisValueLabel {
              if let intValue = value.as(Int.self) {
                Text("\(intValue)%")
                  .font(TrainerFont.label(11, weight: .semibold))
                  .foregroundStyle(TrainerColor.secondaryText)
              }
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: completionData.map(\.label)) { value in
            AxisGridLine().foregroundStyle(.clear)
            AxisValueLabel {
              if let label = value.as(String.self) {
                Text(label)
                  .font(TrainerFont.label(10, weight: .semibold))
                  .foregroundStyle(TrainerColor.tertiaryText)
              }
            }
          }
        }
      }
    }
  }

  private var painSummary: String {
    guard let first = painPoints.first, let last = painPoints.last else {
      return "-"
    }
    let delta = last - first
    return delta <= 0 ? String(format: "%.1f 감소", abs(delta)) : String(format: "%.1f 증가", delta)
  }

  private var completionSummary: String {
    guard let last = completionPoints.last else {
      return "-"
    }
    return "\(Int(last))%"
  }

  private func chartBlock<Content: View>(
    title: String,
    value: String,
    caption: String,
    color: Color,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(TrainerFont.title(20, weight: .bold))
            .foregroundStyle(TrainerColor.primaryText)
          Text(caption)
            .font(TrainerFont.body(13, weight: .medium))
            .foregroundStyle(TrainerColor.secondaryText)
        }
        Spacer()
        StatusCapsule(text: value, color: color)
      }

      content()
        .frame(height: 190)
        .chartPlotStyle { plotArea in
          plotArea
            .background(TrainerColor.quietFill.opacity(0.50))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 4)
    }
  }
}

struct LegendDot: View {
  let label: String
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(label)
        .font(TrainerFont.label(12, weight: .semibold))
        .foregroundStyle(TrainerColor.secondaryText)
    }
  }
}

struct PaperLines: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        TrainerColor.card
        Path { path in
          let spacing: CGFloat = 36
          var y = spacing
          while y < geometry.size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            y += spacing
          }
        }
        .stroke(Color(hex: 0xE6E6EA), lineWidth: 1)
      }
    }
  }
}

struct PencilCanvas: UIViewRepresentable {
  @Binding var drawing: PKDrawing
  @Binding var selectedTool: String
  @Binding var undoSignal: Int

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.delegate = context.coordinator
    canvas.backgroundColor = .clear
    canvas.isOpaque = false
    canvas.drawingPolicy = .anyInput
    canvas.tool = Self.tool(for: selectedTool)
    canvas.drawing = drawing
    return canvas
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {
    uiView.tool = Self.tool(for: selectedTool)
    if context.coordinator.lastUndoSignal != undoSignal {
      context.coordinator.lastUndoSignal = undoSignal
      if uiView.undoManager?.canUndo == true {
        uiView.undoManager?.undo()
      } else if !uiView.drawing.strokes.isEmpty {
        uiView.drawing = PKDrawing(strokes: Array(uiView.drawing.strokes.dropLast()))
      }
      drawing = uiView.drawing
      return
    }
    if uiView.drawing != drawing {
      uiView.drawing = drawing
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(drawing: $drawing, undoSignal: undoSignal)
  }

  private static func tool(for selectedTool: String) -> PKTool {
    switch selectedTool {
    case "marker":
      return PKInkingTool(.marker, color: UIColor.systemYellow.withAlphaComponent(0.85), width: 12)
    case "eraser":
      return PKEraserTool(.bitmap)
    default:
      return PKInkingTool(.pen, color: UIColor.label, width: 3)
    }
  }

  final class Coordinator: NSObject, PKCanvasViewDelegate {
    @Binding var drawing: PKDrawing
    var lastUndoSignal: Int

    init(drawing: Binding<PKDrawing>, undoSignal: Int) {
      _drawing = drawing
      lastUndoSignal = undoSignal
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      drawing = canvasView.drawing
    }
  }
}

struct PencilToolbar: View {
  @Binding var selectedTool: String
  @Binding var undoSignal: Int
  let onIncreasePain: () -> Void
  let onAddROM: () -> Void
  let onAddMMT: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      toolButton(TrainerSymbol.pencil, tool: "pen")
        .trainerLabel("TR-SOAP-10-PEN")
      toolButton(TrainerSymbol.highlighter, tool: "marker")
        .trainerLabel("TR-SOAP-10-MARKER")
      toolButton(TrainerSymbol.eraser, tool: "eraser")
        .trainerLabel("TR-SOAP-10-ERASER")
      Button {
        undoSignal += 1
      } label: {
        Image(systemName: TrainerSymbol.undo)
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      .foregroundStyle(TrainerColor.secondaryText)
      .trainerLabel("TR-SOAP-10-UNDO")

      Divider().frame(height: 24)

      quickChip("+통증", action: onIncreasePain)
        .trainerLabel("TR-SOAP-10-PAIN")
      quickChip("+ROM", action: onAddROM)
        .trainerLabel("TR-SOAP-10-ROM")
      quickChip("+MMT", action: onAddMMT)
        .trainerLabel("TR-SOAP-10-MMT")
    }
    .padding(9)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .trainerLabel("TR-SOAP-10")
  }

  private func toolButton(_ symbol: String, tool: String) -> some View {
    Button {
      selectedTool = tool
    } label: {
      Image(systemName: symbol)
        .frame(width: 36, height: 36)
        .foregroundStyle(selectedTool == tool ? TrainerColor.blue : TrainerColor.secondaryText)
        .background(
          selectedTool == tool ? TrainerColor.blue.opacity(0.12) : Color.clear,
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
    .buttonStyle(.plain)
  }

  private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(TrainerFont.label(13, weight: .semibold))
        .foregroundStyle(TrainerColor.primaryText)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(TrainerColor.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}
