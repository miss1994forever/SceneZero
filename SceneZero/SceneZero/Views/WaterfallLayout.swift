import SwiftUI

struct WaterfallLayout: Layout {
    let minimumColumnWidth: Double
    let maximumColumns: Int
    let spacing: Double

    init(
        minimumColumnWidth: Double = 160,
        maximumColumns: Int = 3,
        spacing: Double = 14
    ) {
        self.minimumColumnWidth = minimumColumnWidth
        self.maximumColumns = maximumColumns
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layoutResult(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layoutResult(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )

        for (index, frame) in result.frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layoutResult(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, frames: [CGRect]) {
        let width = max(proposal.width ?? minimumColumnWidth, 1)
        let possibleColumns = Int((width + spacing) / (minimumColumnWidth + spacing))
        let columnCount = max(1, min(maximumColumns, possibleColumns))
        let totalSpacing = Double(max(0, columnCount - 1)) * spacing
        let columnWidth = max(1, (width - totalSpacing) / Double(columnCount))
        var columnHeights = Array(repeating: 0.0, count: columnCount)
        var frames: [CGRect] = []

        for subview in subviews {
            let column = columnHeights.indices.min {
                columnHeights[$0] < columnHeights[$1]
            } ?? 0
            let size = subview.sizeThatFits(
                ProposedViewSize(width: columnWidth, height: nil)
            )
            let origin = CGPoint(
                x: Double(column) * (columnWidth + spacing),
                y: columnHeights[column]
            )
            frames.append(CGRect(origin: origin, size: CGSize(width: columnWidth, height: size.height)))
            columnHeights[column] += size.height + spacing
        }

        let height = max(0, (columnHeights.max() ?? 0) - (subviews.isEmpty ? 0 : spacing))
        return (CGSize(width: width, height: height), frames)
    }
}
