import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"
import { sankey, sankeyLinkHorizontal, sankeyJustify } from "d3-sankey"

export default class extends Controller {
  static values = {
    nodes: Array,
    links: Array,
    totalStarted: Number
  }

  connect() {
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  render() {
    const container = this.element
    container.innerHTML = ""

    const nodes = this.nodesValue.map(n => ({ ...n }))
    const links = this.linksValue.map(l => ({ ...l }))

    if (nodes.length === 0 || links.length === 0) {
      container.innerHTML = '<div class="dashboard-empty">No application data yet.</div>'
      return
    }

    const width = container.clientWidth || 720
    const height = 320
    const margin = { top: 12, right: 140, bottom: 12, left: 12 }

    const svg = d3.select(container)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "funnel-svg")

    const sankeyGen = sankey()
      .nodeWidth(18)
      .nodePadding(14)
      .nodeAlign(sankeyJustify)
      .extent([[margin.left, margin.top], [width - margin.right, height - margin.bottom]])

    const graph = sankeyGen({
      nodes: nodes,
      links: links
    })

    // Color scale: progress nodes blue, drop nodes red, rejected dark red
    const colorFor = (node) => {
      if (node.rejected) return "#991b1b"
      if (node.drop) return "#ef4444"
      return "#2563eb"
    }

    // Links
    svg.append("g")
      .attr("fill", "none")
      .attr("stroke-opacity", 0.4)
      .selectAll("path")
      .data(graph.links)
      .join("path")
      .attr("d", sankeyLinkHorizontal())
      .attr("stroke", d => colorFor(d.target))
      .attr("stroke-width", d => Math.max(1, d.width))
      .append("title")
      .text(d => `${d.source.name} → ${d.target.name}\n${d.value} applications`)

    // Nodes
    const nodeG = svg.append("g")
      .selectAll("g")
      .data(graph.nodes)
      .join("g")

    nodeG.append("rect")
      .attr("x", d => d.x0)
      .attr("y", d => d.y0)
      .attr("height", d => Math.max(1, d.y1 - d.y0))
      .attr("width", d => d.x1 - d.x0)
      .attr("fill", d => colorFor(d))
      .append("title")
      .text(d => `${d.name}\n${d.value} applications`)

    nodeG.append("text")
      .attr("x", d => d.x0 < width / 2 ? d.x1 + 6 : d.x0 - 6)
      .attr("y", d => (d.y1 + d.y0) / 2)
      .attr("dy", "0.35em")
      .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
      .attr("font-size", "12px")
      .attr("font-weight", "600")
      .attr("fill", "#0f172a")
      .text(d => `${d.name} (${d.value})`)
  }
}
