import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    capitalUtilisation: Number,
    capitalRaised: Number,
    capitalDeployed: Number,
    funderPoolData: Array,
    monthlyPlData: Object,
    funderBreakdown: Array
  }

  connect() {
    this.charts = []
    this.loadChartJS()
  }

  disconnect() {
    if (this.initTimer) clearTimeout(this.initTimer)
    this.charts.forEach(c => c.destroy())
  }

  async loadChartJS() {
    try {
      await import("chart.js")
      this.ChartJS = window.Chart
    } catch (e) {
      this.ChartJS = window.Chart
    }

    if (this.ChartJS) {
      this.initCharts()
    } else {
      this.pollForChart(0)
    }
  }

  pollForChart(attempt) {
    if (attempt >= 20) return
    this.initTimer = setTimeout(() => {
      if (window.Chart) {
        this.ChartJS = window.Chart
        this.initCharts()
      } else {
        this.pollForChart(attempt + 1)
      }
    }, 250)
  }

  initCharts() {
    this.renderCapitalGauge()
    this.renderPoolBreakdownChart()
    this.renderPlTrendChart()
    this.renderFunderBreakdownChart()
  }

  renderCapitalGauge() {
    const ctx = this.element.querySelector("[data-chart=capital-gauge]")
    if (!ctx) return

    const util = this.capitalUtilisationValue
    const remaining = Math.max(0, 100 - util)
    const color = util > 80 ? "#ef4444" : util > 50 ? "#f59e0b" : "#10b981"

    const chart = new this.ChartJS(ctx, {
      type: "doughnut",
      data: {
        labels: ["Deployed", "Available"],
        datasets: [{
          data: [util, remaining],
          backgroundColor: [color, "rgba(226, 232, 240, 0.5)"],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "75%",
        rotation: -90,
        circumference: 180,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.label}: ${item.parsed.toFixed(1)}%`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderPoolBreakdownChart() {
    const ctx = this.element.querySelector("[data-chart=pool-breakdown]")
    if (!ctx) return

    const pools = this.funderPoolDataValue
    if (!pools.length) return

    const labels = pools.map(p => p.name)
    const allocated = pools.map(p => p.allocated / 1000)
    const available = pools.map(p => (p.capacity - p.allocated) / 1000)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Allocated ($k)",
            data: allocated,
            backgroundColor: "rgba(59, 130, 246, 0.8)",
            borderRadius: { topLeft: 6, bottomLeft: 6 },
            borderSkipped: false
          },
          {
            label: "Available ($k)",
            data: available,
            backgroundColor: "rgba(226, 232, 240, 0.8)",
            borderRadius: { topRight: 6, bottomRight: 6 },
            borderSkipped: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 10 },
              color: "#64748b",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.dataset.label}: $${item.parsed.x.toFixed(0)}k`
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            }
          },
          y: {
            stacked: true,
            grid: { display: false },
            ticks: { color: "#334155", font: { size: 11 } }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderPlTrendChart() {
    const ctx = this.element.querySelector("[data-chart=pl-trend]")
    if (!ctx) return

    const plData = this.monthlyPlDataValue
    const labels = Object.keys(plData)
    if (!labels.length) return

    const monthlyValues = labels.map(k => plData[k].monthly / 1000)
    const cumulativeValues = labels.map(k => plData[k].cumulative / 1000)

    const monthlyColors = monthlyValues.map(v =>
      v >= 0 ? "rgba(16, 185, 129, 0.7)" : "rgba(239, 68, 68, 0.7)"
    )

    const gradient = ctx.getContext("2d").createLinearGradient(0, 0, 0, 280)
    gradient.addColorStop(0, "rgba(37, 99, 235, 0.15)")
    gradient.addColorStop(1, "rgba(37, 99, 235, 0.02)")

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Monthly P&L ($k)",
            data: monthlyValues,
            backgroundColor: monthlyColors,
            borderRadius: 4,
            borderSkipped: false,
            order: 2,
            yAxisID: "y"
          },
          {
            label: "Cumulative P&L ($k)",
            data: cumulativeValues,
            type: "line",
            borderColor: "#2563eb",
            backgroundColor: gradient,
            fill: true,
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: "#2563eb",
            borderWidth: 2.5,
            order: 1,
            yAxisID: "y1"
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 11 },
              color: "#64748b",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.dataset.label}: $${item.parsed.y.toFixed(1)}k`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 10 }, maxRotation: 45 }
          },
          y: {
            position: "left",
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            },
            title: { display: true, text: "Monthly", color: "#94a3b8", font: { size: 10 } }
          },
          y1: {
            position: "right",
            grid: { drawOnChartArea: false },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            },
            title: { display: true, text: "Cumulative", color: "#94a3b8", font: { size: 10 } }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderFunderBreakdownChart() {
    const ctx = this.element.querySelector("[data-chart=funder-breakdown]")
    if (!ctx) return

    const funders = this.funderBreakdownValue
    if (!funders.length) return

    const labels = funders.map(f => f.name)
    const committed = funders.map(f => f.committed / 1000)
    const deployed = funders.map(f => f.deployed / 1000)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Committed ($k)",
            data: committed,
            backgroundColor: "rgba(139, 92, 246, 0.7)",
            borderRadius: 6,
            borderSkipped: false
          },
          {
            label: "Deployed ($k)",
            data: deployed,
            backgroundColor: "rgba(59, 130, 246, 0.8)",
            borderRadius: 6,
            borderSkipped: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 11 },
              color: "#64748b",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.dataset.label}: $${item.parsed.y.toFixed(0)}k`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 11, weight: "600" } }
          },
          y: {
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }
}
