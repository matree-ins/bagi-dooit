import WidgetKit

struct QuickEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntryTimeline { QuickEntryTimeline(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntryTimeline) -> Void) {
        completion(QuickEntryTimeline(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntryTimeline>) -> Void) {
        completion(Timeline(entries: [QuickEntryTimeline(date: .now)], policy: .never))
    }
}
