import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"
import * as topojson from "topojson-client"

export default class extends Controller {
  static values = {
    regions: Array,
    atlasUrl: String
  }

  async connect() {
    this.atlas = await this.loadAtlas()
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  async loadAtlas() {
    const url = this.atlasUrlValue || "/data/world-110m.json"
    try {
      const resp = await fetch(url)
      if (!resp.ok) throw new Error(`Failed to load atlas: ${resp.status}`)
      return await resp.json()
    } catch (e) {
      console.error("[regional-choropleth] atlas load failed", e)
      return null
    }
  }

  render() {
    if (!this.atlas) {
      this.element.innerHTML = '<div class="dashboard-empty">Map data unavailable.</div>'
      return
    }
    this.element.innerHTML = ""

    const width = this.element.clientWidth || 720
    const height = 360

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "trend-chart-svg")

    const countries = topojson.feature(this.atlas, this.atlas.objects.countries)

    const projection = d3.geoNaturalEarth1().fitSize([width, height], countries)
    const path = d3.geoPath(projection)

    // Index regions by ISO code
    const byIso = new Map(this.regionsValue.map(r => [r.iso, r]))
    const maxCapital = d3.max(this.regionsValue, r => r.capital) || 1

    // Color scale for active regions
    const colorScale = d3.scaleSequential([0, maxCapital], d3.interpolateBlues)

    // All countries (muted)
    svg.append("g")
      .selectAll("path")
      .data(countries.features)
      .join("path")
      .attr("d", path)
      .attr("fill", d => {
        const iso = String(d.id).padStart(3, "0")
        const region = byIso.get(iso)
        return region && region.capital > 0 ? colorScale(region.capital) : "#f1f5f9"
      })
      .attr("stroke", d => {
        const iso = String(d.id).padStart(3, "0")
        return byIso.has(iso) ? "#1e293b" : "#e2e8f0"
      })
      .attr("stroke-width", d => {
        const iso = String(d.id).padStart(3, "0")
        return byIso.has(iso) ? 1.5 : 0.5
      })
      .append("title")
      .text(d => {
        const iso = String(d.id).padStart(3, "0")
        const region = byIso.get(iso)
        if (!region) return d.properties && d.properties.name ? d.properties.name : ""
        return `${region.region} · ${region.applications} applications · ${d3.format("$,.0f")(region.capital)} capital`
      })

    // Labels for active regions
    this.regionsValue.forEach(region => {
      const feature = countries.features.find(f => String(f.id).padStart(3, "0") === region.iso)
      if (!feature) return
      const [cx, cy] = path.centroid(feature)
      if (Number.isNaN(cx) || Number.isNaN(cy)) return

      svg.append("circle")
        .attr("cx", cx).attr("cy", cy)
        .attr("r", region.applications > 0 ? 4 + Math.sqrt(region.applications) : 3)
        .attr("fill", "#0f172a")
        .attr("fill-opacity", 0.7)
        .attr("stroke", "#fff")
        .attr("stroke-width", 1)

      svg.append("text")
        .attr("x", cx)
        .attr("y", cy - 10)
        .attr("text-anchor", "middle")
        .attr("font-size", 11)
        .attr("font-weight", 700)
        .attr("fill", "#0f172a")
        .text(region.region)
    })
  }
}
