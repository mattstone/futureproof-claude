import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static targets = [
    "applicationGrowthChart",
    "conversionChart",
    "fumMonthlyChart",
    "fumCumulativeChart",
    "statusDistributionChart",
    "poolUtilizationChart"
  ]

  static values = {
    applicationGrowthData: Object,
    conversionGrowthData: Object,
    monthlyFumData: Object,
    cumulativeFumData: Object,
    statusDistribution: Object,
    poolAllocationData: Array
  }

  connect() {
    this.initializeCharts()
  }

  initializeCharts() {
    // Initialize all D3 charts
    if (this.hasApplicationGrowthChartTarget && this.hasApplicationGrowthDataValue) {
      this.createBarChart(
        this.applicationGrowthChartTarget,
        this.applicationGrowthDataValue,
        { color: 'd3-bar-blue', title: 'Applications' }
      )
    }

    if (this.hasConversionChartTarget && this.hasConversionGrowthDataValue) {
      this.createBarChart(
        this.conversionChartTarget,
        this.conversionGrowthDataValue,
        { color: 'd3-bar-green', title: 'Conversion %', isPercentage: true }
      )
    }

    if (this.hasFumMonthlyChartTarget && this.hasMonthlyFumDataValue) {
      this.createBarChart(
        this.fumMonthlyChartTarget,
        this.monthlyFumDataValue,
        { color: 'd3-bar-purple', title: 'Monthly FUM', isCurrency: true }
      )
    }

    if (this.hasFumCumulativeChartTarget && this.hasCumulativeFumDataValue) {
      this.createAreaChart(
        this.fumCumulativeChartTarget,
        this.cumulativeFumDataValue,
        { color: 'd3-line-orange', title: 'Cumulative FUM', isCurrency: true }
      )
    }

    if (this.hasStatusDistributionChartTarget && this.hasStatusDistributionValue) {
      this.createHorizontalBarChart(
        this.statusDistributionChartTarget,
        this.statusDistributionValue
      )
    }

    if (this.hasPoolUtilizationChartTarget && this.hasPoolAllocationDataValue) {
      this.createPoolUtilizationChart(
        this.poolUtilizationChartTarget,
        this.poolAllocationDataValue
      )
    }
  }

  createBarChart(target, data, options = {}) {
    // Clear previous chart
    d3.select(target).selectAll("*").remove()

    const margin = { top: 20, right: 30, bottom: 60, left: 60 }
    const width = target.clientWidth - margin.left - margin.right
    const height = 300 - margin.top - margin.bottom

    const svg = d3.select(target)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Convert data to array format
    const chartData = Object.entries(data).map(([key, value]) => ({
      label: key,
      value: parseFloat(value) || 0
    }))

    // Scales
    const xScale = d3.scaleBand()
      .domain(chartData.map(d => d.label))
      .range([0, width])
      .padding(0.2)

    const yScale = d3.scaleLinear()
      .domain([0, d3.max(chartData, d => d.value)])
      .range([height, 0])

    // Axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))
      .selectAll("text")
      .attr("text-anchor", "end")
      .attr("dx", "-.8em")
      .attr("dy", ".15em")
      .attr("transform", "rotate(-45)")

    g.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => {
        if (options.isCurrency) {
          return this.formatCurrency(d)
        } else if (options.isPercentage) {
          return d + '%'
        }
        return d
      }))

    // Bars with animation - using CSS classes instead of inline styles
    g.selectAll(".bar")
      .data(chartData)
      .enter().append("rect")
      .attr("class", `bar ${options.color || 'd3-bar-blue'}`)
      .attr("x", d => xScale(d.label))
      .attr("width", xScale.bandwidth())
      .attr("y", height)
      .attr("height", 0)
      .transition()
      .duration(800)
      .attr("y", d => yScale(d.value))
      .attr("height", d => height - yScale(d.value))

    // Add value labels on bars
    g.selectAll(".label")
      .data(chartData)
      .enter().append("text")
      .attr("class", "label")
      .attr("x", d => xScale(d.label) + xScale.bandwidth() / 2)
      .attr("y", height)
      .attr("text-anchor", "middle")
      .transition()
      .duration(800)
      .attr("y", d => yScale(d.value) - 5)
      .text(d => {
        if (options.isCurrency) {
          return this.formatCurrency(d.value)
        } else if (options.isPercentage) {
          return d.value + '%'
        }
        return d.value
      })
  }

  createAreaChart(target, data, options = {}) {
    // Clear previous chart
    d3.select(target).selectAll("*").remove()

    const margin = { top: 20, right: 30, bottom: 60, left: 60 }
    const width = target.clientWidth - margin.left - margin.right
    const height = 300 - margin.top - margin.bottom

    const svg = d3.select(target)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Convert data to array format
    const chartData = Object.entries(data).map(([key, value], index) => ({
      label: key,
      value: parseFloat(value) || 0,
      index: index
    }))

    // Scales
    const xScale = d3.scaleLinear()
      .domain([0, chartData.length - 1])
      .range([0, width])

    const yScale = d3.scaleLinear()
      .domain([0, d3.max(chartData, d => d.value)])
      .range([height, 0])

    // Line generator
    const line = d3.line()
      .x(d => xScale(d.index))
      .y(d => yScale(d.value))
      .curve(d3.curveMonotoneX)

    // Area generator
    const area = d3.area()
      .x(d => xScale(d.index))
      .y0(height)
      .y1(d => yScale(d.value))
      .curve(d3.curveMonotoneX)

    // Add gradient
    const gradient = svg.append("defs")
      .append("linearGradient")
      .attr("id", "area-gradient")
      .attr("gradientUnits", "userSpaceOnUse")
      .attr("x1", 0).attr("y1", height)
      .attr("x2", 0).attr("y2", 0)

    gradient.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", '#f59e0b')
      .attr("stop-opacity", 0.1)

    gradient.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", '#f59e0b')
      .attr("stop-opacity", 0.6)

    // Add area with animation - using CSS class
    g.append("path")
      .datum(chartData)
      .attr("class", "d3-area-gradient d3-area-hidden")
      .attr("d", area)
      .transition()
      .duration(1000)
      .attr("class", "d3-area-gradient")

    // Add line - using CSS class
    g.append("path")
      .datum(chartData)
      .attr("class", `d3-line ${options.color || 'd3-line-orange'}`)
      .attr("d", line)

    // Axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale)
        .tickValues(chartData.map(d => d.index))
        .tickFormat(i => chartData[i].label)
      )
      .selectAll("text")
      .attr("text-anchor", "end")
      .attr("dx", "-.8em")
      .attr("dy", ".15em")
      .attr("transform", "rotate(-45)")

    g.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => {
        if (options.isCurrency) {
          return this.formatCurrency(d)
        }
        return d
      }))

    // Add dots for data points - using CSS classes
    g.selectAll(".dot")
      .data(chartData)
      .enter().append("circle")
      .attr("class", "d3-dot d3-dot-orange d3-dot-hidden")
      .attr("cx", d => xScale(d.index))
      .attr("cy", d => yScale(d.value))
      .attr("r", 4)
      .transition()
      .duration(1200)
      .attr("class", "d3-dot d3-dot-orange")
  }

  createHorizontalBarChart(target, data) {
    // Clear previous chart
    d3.select(target).selectAll("*").remove()

    const margin = { top: 20, right: 30, bottom: 30, left: 120 }
    const width = target.clientWidth - margin.left - margin.right
    const height = 400 - margin.top - margin.bottom

    const svg = d3.select(target)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Convert data to array format
    const chartData = Object.entries(data).map(([key, value]) => ({
      label: key,
      value: parseFloat(value) || 0
    }))

    const colorMap = {
      'Created': 'd3-bar-created',
      'User Details': 'd3-bar-user-details',
      'Property Details': 'd3-bar-property-details',
      'Income & Loan': 'd3-bar-income-loan',
      'Submitted': 'd3-bar-submitted',
      'Processing': 'd3-bar-processing',
      'Rejected': 'd3-bar-rejected',
      'Accepted': 'd3-bar-accepted'
    }

    // Scales
    const xScale = d3.scaleLinear()
      .domain([0, d3.max(chartData, d => d.value)])
      .range([0, width])

    const yScale = d3.scaleBand()
      .domain(chartData.map(d => d.label))
      .range([0, height])
      .padding(0.2)

    // Axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))

    g.append("g")
      .call(d3.axisLeft(yScale))

    // Bars with animation - using CSS classes
    g.selectAll(".bar")
      .data(chartData)
      .enter().append("rect")
      .attr("class", d => `bar ${colorMap[d.label] || 'd3-bar-blue'}`)
      .attr("x", 0)
      .attr("y", d => yScale(d.label))
      .attr("width", 0)
      .attr("height", yScale.bandwidth())
      .transition()
      .duration(800)
      .attr("width", d => xScale(d.value))

    // Add value labels
    g.selectAll(".label")
      .data(chartData)
      .enter().append("text")
      .attr("class", "label")
      .attr("x", 5)
      .attr("y", d => yScale(d.label) + yScale.bandwidth() / 2)
      .attr("dy", "0.35em")
      .transition()
      .duration(800)
      .attr("x", d => xScale(d.value) - 5)
      .text(d => d.value)
  }

  createPoolUtilizationChart(target, data) {
    // Clear previous chart
    d3.select(target).selectAll("*").remove()

    const margin = { top: 20, right: 30, bottom: 30, left: 150 }
    const width = target.clientWidth - margin.left - margin.right
    const height = Math.max(300, data.length * 50) - margin.top - margin.bottom

    const svg = d3.select(target)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Scales
    const xScale = d3.scaleLinear()
      .domain([0, 100])
      .range([0, width])

    const yScale = d3.scaleBand()
      .domain(data.map(d => d.name))
      .range([0, height])
      .padding(0.3)

    // Background bars - using CSS class
    g.selectAll(".bg-bar")
      .data(data)
      .enter().append("rect")
      .attr("class", "d3-bg-bar")
      .attr("x", 0)
      .attr("y", d => yScale(d.name))
      .attr("width", width)
      .attr("height", yScale.bandwidth())

    // Utilization bars with animation - using CSS classes
    g.selectAll(".util-bar")
      .data(data)
      .enter().append("rect")
      .attr("class", d => {
        const utilization = parseFloat(d.utilization) || 0
        if (utilization >= 80) return "bar d3-util-high"
        if (utilization >= 60) return "bar d3-util-medium"
        return "bar d3-util-low"
      })
      .attr("x", 0)
      .attr("y", d => yScale(d.name))
      .attr("width", 0)
      .attr("height", yScale.bandwidth())
      .attr("rx", 4)
      .transition()
      .duration(1000)
      .attr("width", d => xScale(parseFloat(d.utilization) || 0))

    // Pool name labels
    g.selectAll(".name-label")
      .data(data)
      .enter().append("text")
      .attr("class", "name-label")
      .attr("x", -10)
      .attr("y", d => yScale(d.name) + yScale.bandwidth() / 2)
      .attr("dy", "0.35em")
      .attr("text-anchor", "end")
      .text(d => d.name.length > 20 ? d.name.substring(0, 17) + "..." : d.name)

    // Percentage labels
    g.selectAll(".percent-label")
      .data(data)
      .enter().append("text")
      .attr("class", "percent-label")
      .attr("x", d => xScale(parseFloat(d.utilization) || 0) + 5)
      .attr("y", d => yScale(d.name) + yScale.bandwidth() / 2)
      .attr("dy", "0.35em")
      .text(d => `${(parseFloat(d.utilization) || 0).toFixed(1)}%`)
  }

  formatCurrency(amount) {
    if (amount >= 1000000000) {
      return `$${(amount / 1000000000).toFixed(1)}B`
    } else if (amount >= 1000000) {
      return `$${(amount / 1000000).toFixed(1)}M`
    } else if (amount >= 1000) {
      return `$${(amount / 1000).toFixed(1)}K`
    }
    return `$${amount.toLocaleString()}`
  }
}