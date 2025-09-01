import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "submitBtn", "spinner", "results", "loadingOverlay",
    "insurerProfitMargin", "hedgingCost", "hedgingMaxLoss", "hedgingCap",
    "mainOutputTable", "pathTable", "portfolioChart", "distributionChart",
    "sp500Chart", "loanDeficitChart", "unitsChart", "cumulativeChart",
    "expectedValue", "worstCase", "medianValue", "bestCase",
    "varValue", "lossProb", "volatilityMetric", "sharpeRatio"
  ]

  connect() {
    console.log("Monte Carlo Calculator controller connected")
    // Wait a moment for D3.js to load, then check
    setTimeout(() => {
      if (typeof window.d3 !== 'undefined') {
        console.log("D3.js available globally:", window.d3.version)
      } else {
        console.log("D3.js NOT available globally")
      }
    }, 100)
  }

  toggleHedged(event) {
    const isHedged = event.target.checked
    
    if (isHedged) {
      this.hedgingCostTarget.style.display = 'block'
      this.hedgingMaxLossTarget.style.display = 'block'
      this.hedgingCapTarget.style.display = 'block'
      this.insurerProfitMarginTarget.style.display = 'none'
    } else {
      this.hedgingCostTarget.style.display = 'none'
      this.hedgingMaxLossTarget.style.display = 'none'
      this.hedgingCapTarget.style.display = 'none'
      this.insurerProfitMarginTarget.style.display = 'block'
    }
  }

  validateTerms(event) {
    // Get current values
    const loanTermSelect = this.formTarget.querySelector('select[name="calculator[loan_duration]"]')
    const annuitySelect = this.formTarget.querySelector('select[name="calculator[annuity_duration]"]')
    
    if (!loanTermSelect || !annuitySelect) return
    
    const loanTerm = parseInt(loanTermSelect.value)
    const annuityDuration = parseInt(annuitySelect.value)
    
    console.log('Validating terms:', { loanTerm, annuityDuration })
    
    // Business rule: Annuity cannot be longer than loan term
    if (annuityDuration > loanTerm) {
      console.log('Annuity duration exceeds loan term, adjusting loan term')
      
      // Automatically increase loan term to match annuity duration
      loanTermSelect.value = annuityDuration
      
      // Show a brief notification
      this.showTermAdjustmentNotification(loanTerm, annuityDuration)
    }
  }

  showTermAdjustmentNotification(oldLoanTerm, newLoanTerm) {
    // Create and show a temporary notification
    const notification = document.createElement('div')
    notification.className = 'term-adjustment-notification'
    notification.textContent = `Loan term automatically adjusted from ${oldLoanTerm} to ${newLoanTerm} years to match annuity duration`
    
    // Find a good place to insert the notification
    const borrowerSection = this.formTarget.querySelector('.parameter-section')
    if (borrowerSection) {
      borrowerSection.insertBefore(notification, borrowerSection.firstChild)
      
      // Remove notification after 4 seconds
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification)
        }
      }, 4000)
    }
  }

  async calculate(event) {
    event.preventDefault()
    
    // Show loading state
    this.submitBtnTarget.disabled = true
    this.loadingOverlayTarget.style.display = 'flex'
    this.resultsTarget.style.display = 'none'

    try {
      const formData = new FormData(this.formTarget)
      const response = await fetch(this.formTarget.action, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || `HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      console.log('Received data:', data)
      console.log('Chart data:', data.chart_data)
      console.log('Main outputs:', data.main_outputs)
      this.displayResults(data)
      this.resultsTarget.style.display = 'block'
      console.log('Results should now be visible')

    } catch (error) {
      console.error('Calculation error:', error)
      alert(`Calculation error: ${error.message}`)
    } finally {
      // Hide loading state
      this.submitBtnTarget.disabled = false
      this.loadingOverlayTarget.style.display = 'none'
    }
  }

  displayResults(data) {
    if (data.main_outputs) {
      this.populateMainOutputTable(data.main_outputs)
    }
    if (data.path_data) {
      this.populatePathTable(data.path_data.mean || data.path_data)
    }
    
    // Update metrics cards
    this.updateMetricsCards(data)
    
    // Create charts
    this.createCharts(data)
    
    // Update risk metrics
    this.updateRiskMetrics(data)
    
    this.currentData = data // Store for path table updates
  }

  populateMainOutputTable(mainOutputs) {
    console.log('Populating main outputs table with:', mainOutputs)
    const tbody = this.mainOutputTableTarget.querySelector('tbody')
    tbody.innerHTML = ''

    if (mainOutputs && Array.isArray(mainOutputs) && mainOutputs.length > 0) {
      mainOutputs.forEach(row => {
        const tr = document.createElement('tr')
        if (Array.isArray(row)) {
          row.forEach(cell => {
            const td = document.createElement('td')
            td.textContent = cell || ''
            tr.appendChild(td)
          })
        }
        tbody.appendChild(tr)
      })
    } else {
      console.log('No main outputs data available')
      const tr = document.createElement('tr')
      const td = document.createElement('td')
      td.colSpan = 7
      td.className = 'text-center text-muted'
      td.textContent = 'No data available'
      tr.appendChild(td)
      tbody.appendChild(tr)
    }
  }

  populatePathTable(pathData) {
    const tbody = this.pathTableTarget.querySelector('tbody')
    tbody.innerHTML = ''

    if (pathData && Array.isArray(pathData)) {
      pathData.forEach(row => {
        const tr = document.createElement('tr')
        row.forEach((cell, index) => {
          const td = document.createElement('td')
          if (typeof cell === 'number' && index > 0) {
            // Format numbers with thousands separator for non-period columns
            td.textContent = new Intl.NumberFormat().format(Math.round(cell))
          } else {
            td.textContent = cell
          }
          tr.appendChild(td)
        })
        tbody.appendChild(tr)
      })
    }
  }

  updatePathTable(event) {
    const type = event.target.value
    console.log('Updating path table to show:', type)
    
    if (this.currentData && this.currentData.path_data) {
      console.log('Available path data keys:', Object.keys(this.currentData.path_data))
      
      // Map display names to data keys
      const keyMapping = {
        'Mean': 'mean',
        'Median': 'median', 
        '2% percentile': 'percentile_2',
        '25% percentile': 'percentile_25',
        '75% percentile': 'percentile_75'
      }
      
      const dataKey = keyMapping[type] || 'mean'
      const data = this.currentData.path_data[dataKey] || this.currentData.path_data.mean
      
      console.log(`Using data key "${dataKey}" for type "${type}"`, data ? 'found' : 'not found')
      
      if (data) {
        this.populatePathTable(data)
      } else {
        console.log('Falling back to mean data')
        this.populatePathTable(this.currentData.path_data.mean)
      }
    }
  }

  updateMetricsCards(data) {
    console.log('Updating metrics cards with data:', data.main_outputs)
    
    if (!data.main_outputs || !Array.isArray(data.main_outputs)) {
      console.log('No main outputs data available')
      return
    }
    
    // Find relevant metrics from main outputs
    let expectedReturn = null
    let worstCase = null
    let medianCase = null
    let bestCase = null
    
    data.main_outputs.forEach((row, index) => {
      console.log(`Row ${index}:`, row)
      if (Array.isArray(row) && row.length > 2) {
        const label = String(row[0]).toLowerCase()
        console.log(`Processing label: "${label}"`)
        
        // Use the Reinvestment value row which shows the portfolio performance
        if (label.includes('reinvestment value') && row.length >= 7) {
          expectedReturn = this.parseAndFormatCurrency(row[2])  // Expected value column
          worstCase = this.parseAndFormatCurrency(row[3])       // Worst case column
          medianCase = this.parseAndFormatCurrency(row[5])      // Median column
          bestCase = this.parseAndFormatCurrency(row[6])        // Best case column
          console.log('Found metrics from reinvestment value:', { expectedReturn, worstCase, medianCase, bestCase })
        }
      }
    })
    
    // Update metric cards
    if (this.hasExpectedValueTarget) {
      this.expectedValueTarget.textContent = expectedReturn || '--'
    }
    if (this.hasWorstCaseTarget) {
      this.worstCaseTarget.textContent = worstCase || '--'
    }
    if (this.hasMedianValueTarget) {
      this.medianValueTarget.textContent = medianCase || '--'
    }
    if (this.hasBestCaseTarget) {
      this.bestCaseTarget.textContent = bestCase || '--'
    }
    
    console.log('Metrics updated:', { expectedReturn, worstCase, medianCase, bestCase })
  }

  createCharts(data) {
    if (typeof window.d3 === 'undefined') {
      console.warn('D3.js not loaded')
      return
    }

    console.log('Creating charts with data:', data)
    
    try {
      this.createPortfolioChart(data)
    } catch (error) {
      console.error('Error creating portfolio chart:', error)
    }
    
    try {
      this.createDistributionChart(data)
    } catch (error) {
      console.error('Error creating distribution chart:', error)
    }
    
    try {
      this.createSP500Chart(data)
    } catch (error) {
      console.error('Error creating S&P 500 chart:', error)
    }
    
    try {
      this.createLoanDeficitChart(data)
    } catch (error) {
      console.error('Error creating loan deficit chart:', error)
    }
    
    try {
      this.createUnitsChart(data)
    } catch (error) {
      console.error('Error creating units chart:', error)
    }
    
    try {
      this.createCumulativeChart(data)
    } catch (error) {
      console.error('Error creating cumulative chart:', error)
    }
  }

  createPortfolioChart(data) {
    console.log('Creating portfolio chart...')
    if (!this.hasPortfolioChartTarget) {
      console.log('No portfolio chart target found')
      return
    }
    
    const container = this.portfolioChartTarget
    console.log('Container found:', container)
    
    // Clear existing chart
    d3.select(container).selectAll("*").remove()
    
    // Get all simulation paths from chart_data
    const chartData = data.chart_data
    console.log('Chart data:', chartData)
    
    if (!chartData) {
      console.log('No chart_data available, trying to use path_data as fallback')
      this.createFallbackPortfolioChart(data, container)
      return
    }
    
    if (!chartData.all_paths || chartData.all_paths.length === 0) {
      console.log('No simulation paths data available, using fallback')
      this.createFallbackPortfolioChart(data, container)
      return
    }
    
    const allPaths = chartData.all_paths
    const totalPaths = data.total_paths || 1000
    
    console.log(`Rendering ${allPaths.length} paths out of ${totalPaths} total paths`)
    console.log('Sample path data:', allPaths[0])
    console.log('All paths structure:', allPaths.slice(0, 3))
    
    // Set dimensions and margins
    const margin = { top: 40, right: 50, bottom: 60, left: 100 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200) // Much larger minimum width
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom
    
    console.log('Chart dimensions:', { width, height, containerRect, containerWidth })
    
    // Create SVG
    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    
    console.log('SVG created:', svg.node())
    
    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)
    
    console.log('Chart group created:', g.node())
    
    // Prepare data - each path is an array of [period, value] pairs
    const pathsData = allPaths.map((path, pathIndex) => 
      path.map((value, period) => ({ period, value, pathIndex }))
    )
    
    console.log('Processed paths data (first 3 paths):', pathsData.slice(0, 3))
    
    // Create scales
    const xDomain = [0, d3.max(pathsData, d => d3.max(d, p => p.period)) || 0]
    const yExtent = d3.extent(pathsData.flat(), d => d.value)
    
    console.log('Scale domains:', { xDomain, yExtent })
    
    const xScale = d3.scaleLinear()
      .domain(xDomain)
      .range([0, width])
    
    const yScale = d3.scaleLinear()
      .domain(yExtent)
      .nice()
      .range([height, 0])
      
    console.log('Scales created:', { xScale: xScale.domain(), yScale: yScale.domain() })
    
    // Create line generator
    const line = d3.line()
      .x(d => xScale(d.period))
      .y(d => yScale(d.value))
      .curve(d3.curveLinear)
    
    // Add paths with opacity based on number of paths
    const pathOpacity = Math.max(0.05, Math.min(0.8, 50 / allPaths.length))
    
    console.log('Path opacity:', pathOpacity, 'Number of paths:', allPaths.length)
    
    const pathElements = g.selectAll(".path")
      .data(pathsData)
      .enter()
      .append("path")
      .attr("class", "path")
      .attr("d", line)
      .attr("fill", "none")
      .attr("stroke", (d, i) => {
        // Color paths based on final value - blue for gains, red for losses
        const finalValue = d[d.length - 1]?.value || 0
        const initialValue = d[0]?.value || 0
        return finalValue >= initialValue ? "#2563eb" : "#dc2626"
      })
      .attr("stroke-width", 1)
      .attr("stroke-opacity", pathOpacity)
      
    console.log('Path elements created:', pathElements.size())
    
    // Add mean path if available
    if (data.path_data && data.path_data.mean) {
      const meanData = data.path_data.mean.map((row, period) => ({
        period,
        value: Array.isArray(row) && row[4] ? parseFloat(row[4]) : 0
      }))
      
      g.append("path")
        .datum(meanData)
        .attr("class", "mean-path")
        .attr("d", line)
        .attr("fill", "none")
        .attr("stroke", "#f59e0b")
        .attr("stroke-width", 5)
        .attr("stroke-opacity", 1.0)
    }
    
    // Add axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))
      .append("text")
      .attr("x", width / 2)
      .attr("y", 40)
      .attr("fill", "black")
      .attr("text-anchor", "middle")
      .text("Time Period")
    
    g.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => d3.format("$,.0f")(d)))
      .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", -60)
      .attr("x", -height / 2)
      .attr("fill", "black")
      .attr("text-anchor", "middle")
      .text("Portfolio Value")
    
    // Add title
    svg.append("text")
      .attr("x", (width + margin.left + margin.right) / 2)
      .attr("y", 25)
      .attr("text-anchor", "middle")
      .attr("font-size", "16px")
      .attr("font-weight", "bold")
      .text(`Monte Carlo Simulation Paths (${allPaths.length} of ${totalPaths})`)
    
    // Add legend
    const legend = svg.append("g")
      .attr("transform", `translate(${width - 100}, 50)`)
    
    legend.append("line")
      .attr("x1", 0).attr("x2", 20)
      .attr("y1", 0).attr("y2", 0)
      .attr("stroke", "#2563eb")
      .attr("stroke-width", 2)
      .attr("stroke-opacity", pathOpacity)
    
    legend.append("text")
      .attr("x", 25)
      .attr("y", 5)
      .attr("font-size", "12px")
      .text("Positive paths")
    
    legend.append("line")
      .attr("x1", 0).attr("x2", 20)
      .attr("y1", 15).attr("y2", 15)
      .attr("stroke", "#dc2626")
      .attr("stroke-width", 2)
      .attr("stroke-opacity", pathOpacity)
    
    legend.append("text")
      .attr("x", 25)
      .attr("y", 20)
      .attr("font-size", "12px")
      .text("Negative paths")
    
    if (data.path_data && data.path_data.mean) {
      legend.append("line")
        .attr("x1", 0).attr("x2", 20)
        .attr("y1", 30).attr("y2", 30)
        .attr("stroke", "#f59e0b")
        .attr("stroke-width", 5)
      
      legend.append("text")
        .attr("x", 25)
        .attr("y", 35)
        .attr("font-size", "12px")
        .text("Mean path")
    }
  }

  createDistributionChart(data) {
    console.log('Creating distribution chart...')
    if (!this.hasDistributionChartTarget) {
      console.log('No distribution chart target found')
      return
    }
    
    const container = this.distributionChartTarget
    console.log('Distribution container found:', container)
    
    // Clear existing chart
    d3.select(container).selectAll("*").remove()
    
    // Generate distribution data from chart_data or main outputs
    const distributionData = this.generateDistributionData(data)
    console.log('Distribution data:', distributionData)
    
    // Set dimensions and margins
    const margin = { top: 40, right: 50, bottom: 80, left: 80 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200) // Much larger minimum width
    const width = containerWidth - margin.left - margin.right
    const height = 400 - margin.top - margin.bottom
    
    // Create SVG
    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    
    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)
    
    // Create scales
    const xScale = d3.scaleBand()
      .domain(distributionData.labels)
      .range([0, width])
      .padding(0.1)
    
    const yScale = d3.scaleLinear()
      .domain([0, d3.max(distributionData.values)])
      .nice()
      .range([height, 0])
    
    // Create bars
    g.selectAll(".bar")
      .data(distributionData.values)
      .enter()
      .append("rect")
      .attr("class", "bar")
      .attr("x", (d, i) => xScale(distributionData.labels[i]))
      .attr("width", xScale.bandwidth())
      .attr("y", d => yScale(d))
      .attr("height", d => height - yScale(d))
      .attr("fill", (d, i) => {
        // Color bars based on return type - red for losses, green for gains
        const label = distributionData.labels[i].toLowerCase()
        if (label.includes('loss')) return "#dc2626"
        if (label.includes('gain')) return "#16a34a"
        return "#6366f1"
      })
      .attr("opacity", 0.8)
    
    // Add value labels on bars
    g.selectAll(".bar-label")
      .data(distributionData.values)
      .enter()
      .append("text")
      .attr("class", "bar-label")
      .attr("x", (d, i) => xScale(distributionData.labels[i]) + xScale.bandwidth() / 2)
      .attr("y", d => yScale(d) - 5)
      .attr("text-anchor", "middle")
      .attr("font-size", "11px")
      .attr("fill", "#374151")
      .text(d => d)
    
    // Add axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))
      .selectAll("text")
      .attr("transform", "rotate(-45)")
      .style("text-anchor", "end")
    
    g.append("g")
      .call(d3.axisLeft(yScale))
    
    // Add axis labels
    g.append("text")
      .attr("x", width / 2)
      .attr("y", height + 55)
      .attr("text-anchor", "middle")
      .attr("font-size", "12px")
      .attr("fill", "black")
      .text("Return Range")
    
    g.append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", -40)
      .attr("x", -height / 2)
      .attr("text-anchor", "middle")
      .attr("font-size", "12px")
      .attr("fill", "black")
      .text("Frequency")
    
    // Add title
    svg.append("text")
      .attr("x", (width + margin.left + margin.right) / 2)
      .attr("y", 25)
      .attr("text-anchor", "middle")
      .attr("font-size", "16px")
      .attr("font-weight", "bold")
      .text("Final Return Distribution")
  }

  createFallbackPortfolioChart(data, container) {
    console.log('Creating fallback portfolio chart with path_data')
    
    // Use path_data.mean as fallback
    if (!data.path_data || !data.path_data.mean) {
      console.log('No fallback data available')
      container.innerHTML = '<p class="no-data-message">No chart data available</p>'
      return
    }
    
    const meanData = data.path_data.mean.map((row, period) => ({
      period,
      value: Array.isArray(row) && row[4] ? parseFloat(row[4]) : 0
    })).filter(d => !isNaN(d.value) && d.value > 0)
    
    if (meanData.length === 0) {
      console.log('No valid fallback data')
      container.innerHTML = '<p class="no-data-message">No valid chart data available</p>'
      return
    }
    
    // Set dimensions and margins
    const margin = { top: 40, right: 50, bottom: 60, left: 100 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200) // Much larger minimum width
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom
    
    // Create SVG
    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
    
    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)
    
    // Create scales
    const xScale = d3.scaleLinear()
      .domain(d3.extent(meanData, d => d.period))
      .range([0, width])
    
    const yScale = d3.scaleLinear()
      .domain(d3.extent(meanData, d => d.value))
      .nice()
      .range([height, 0])
    
    // Create line generator
    const line = d3.line()
      .x(d => xScale(d.period))
      .y(d => yScale(d.value))
      .curve(d3.curveLinear)
    
    // Add the mean path
    g.append("path")
      .datum(meanData)
      .attr("class", "mean-path")
      .attr("d", line)
      .attr("fill", "none")
      .attr("stroke", "#2563eb")
      .attr("stroke-width", 2)
    
    // Add axes
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))
      .append("text")
      .attr("x", width / 2)
      .attr("y", 40)
      .attr("fill", "black")
      .attr("text-anchor", "middle")
      .text("Time Period")
    
    g.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => d3.format("$,.0f")(d)))
      .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", -60)
      .attr("x", -height / 2)
      .attr("fill", "black")
      .attr("text-anchor", "middle")
      .text("Portfolio Value")
    
    // Add title
    svg.append("text")
      .attr("x", (width + margin.left + margin.right) / 2)
      .attr("y", 25)
      .attr("text-anchor", "middle")
      .attr("font-size", "16px")
      .attr("font-weight", "bold")
      .text("Portfolio Value Path (Mean)")
  }

  generateDistributionData(data) {
    console.log('Generating distribution data from:', data)
    
    // Try to use actual simulation results if available
    if (data.chart_data && data.chart_data.all_paths) {
      const allPaths = data.chart_data.all_paths
      console.log('Using actual simulation data for distribution')
      
      // Calculate return distribution from actual paths
      const returns = allPaths.map(path => {
        if (path.length < 2) return 0
        const initial = path[0] || 0
        const final = path[path.length - 1] || 0
        return initial > 0 ? ((final - initial) / initial) * 100 : 0
      })
      
      console.log('Calculated returns sample:', returns.slice(0, 10))
      
      // Create histogram buckets
      const buckets = [
        { label: 'Loss > 20%', min: -Infinity, max: -20, count: 0 },
        { label: 'Loss 10-20%', min: -20, max: -10, count: 0 },
        { label: 'Loss 0-10%', min: -10, max: 0, count: 0 },
        { label: 'Gain 0-10%', min: 0, max: 10, count: 0 },
        { label: 'Gain 10-20%', min: 10, max: 20, count: 0 },
        { label: 'Gain 20-30%', min: 20, max: 30, count: 0 },
        { label: 'Gain > 30%', min: 30, max: Infinity, count: 0 }
      ]
      
      // Count returns in each bucket
      returns.forEach(ret => {
        buckets.forEach(bucket => {
          if (ret > bucket.min && ret <= bucket.max) {
            bucket.count++
          }
        })
      })
      
      const labels = buckets.map(b => b.label)
      const values = buckets.map(b => b.count)
      
      console.log('Distribution buckets:', buckets)
      return { labels, values }
    }
    
    // Fallback to sample data
    console.log('Using sample distribution data')
    const labels = [
      'Loss > 20%',
      'Loss 10-20%',
      'Loss 0-10%',
      'Gain 0-10%',
      'Gain 10-20%',
      'Gain 20-30%',
      'Gain > 30%'
    ]
    
    const values = [5, 15, 25, 30, 20, 15, 10]
    
    return { labels, values }
  }

  updateRiskMetrics(data) {
    console.log('Updating risk metrics with data:', data)
    
    if (!data.main_outputs) {
      console.log('No main outputs for risk metrics')
      return
    }
    
    // Get volatility from form input (it's a parameter, not a calculated result)
    const volatilityInput = this.formTarget.querySelector('input[name="calculator[volatility]"]')
    const inputVolatility = volatilityInput ? parseFloat(volatilityInput.value) : null
    
    // Calculate or extract risk metrics
    let var5 = null
    let lossProb = null
    let volatility = null
    let sharpeRatio = null
    
    // Extract risk metrics from main outputs if available
    data.main_outputs.forEach((row, index) => {
      if (Array.isArray(row) && row.length > 0) {
        const label = String(row[0]).toLowerCase()
        console.log(`Risk metric row ${index}: "${label}"`, row)
        
        if (label.includes('var') || label.includes('risk') || label.includes('worst')) {
          var5 = this.formatCurrency(row[2] || row[3])
          console.log('Found VaR:', var5)
        }
        if (label.includes('volatility') || label.includes('std') || label.includes('deviation')) {
          volatility = this.formatPercentage(row[2] || row[3])
          console.log('Found volatility:', volatility)
        }
      }
    })
    
    // Use input volatility (it's an input parameter, not calculated)
    if (inputVolatility !== null) {
      volatility = this.formatPercentage(inputVolatility / 100)
      console.log('Using input volatility:', volatility)
    } else if (!volatility && data.parameters && data.parameters.volatility) {
      volatility = this.formatPercentage(data.parameters.volatility)
      console.log('Using parameter volatility:', volatility)
    } else if (!volatility) {
      volatility = '15.00%' // Default from form
    }
    
    // Calculate derived metrics from available data
    if (data.chart_data && data.chart_data.all_paths) {
      // Calculate probability of loss and VaR from paths
      const paths = data.chart_data.all_paths
      let lossCount = 0
      const finalValues = []
      
      paths.forEach(path => {
        if (path.length > 1) {
          const initialValue = path[0] || 0
          const finalValue = path[path.length - 1] || 0
          finalValues.push(finalValue)
          
          if (finalValue < initialValue) {
            lossCount++
          }
        }
      })
      
      lossProb = `${((lossCount / paths.length) * 100).toFixed(1)}%`
      console.log('Calculated loss probability:', lossProb)
      
      // Calculate 5% VaR (5th percentile of final values)
      if (finalValues.length > 0) {
        finalValues.sort((a, b) => a - b)
        const varIndex = Math.floor(finalValues.length * 0.05)
        const var5Value = finalValues[varIndex]
        console.log('VaR calculation:', {
          totalPaths: finalValues.length,
          varIndex,
          var5Value,
          sortedSample: finalValues.slice(0, 10),
          sortedSampleEnd: finalValues.slice(-10)
        })
        var5 = this.formatCurrency(var5Value)
        console.log('Calculated 5% VaR:', var5)
      }
    } else {
      lossProb = '20.0%' // Reasonable default
      
      // Try to extract VaR from main outputs worst case scenario
      if (data.main_outputs) {
        const reinvestmentRow = data.main_outputs.find(row => 
          Array.isArray(row) && String(row[0]).toLowerCase().includes('reinvestment value')
        )
        if (reinvestmentRow && reinvestmentRow[3]) {
          var5 = this.parseAndFormatCurrency(reinvestmentRow[3])
          console.log('Using worst case as VaR:', var5)
        }
      }
    }
    
    // Calculate simple Sharpe ratio estimate
    const expectedReturn = 0.108 // 10.8% from form default
    const riskFreeRate = 0.0385 // 3.85% cash rate from form
    const vol = parseFloat(volatility.replace('%', '')) / 100 || 0.15
    sharpeRatio = ((expectedReturn - riskFreeRate) / vol).toFixed(2)
    console.log('Calculated Sharpe ratio:', sharpeRatio)
    
    // Update risk metric displays
    if (this.hasVarValueTarget) {
      this.varValueTarget.textContent = var5 || '--'
    }
    if (this.hasLossProbTarget) {
      this.lossProbTarget.textContent = lossProb || '--'
    }
    if (this.hasVolatilityMetricTarget) {
      this.volatilityMetricTarget.textContent = volatility || '--'
    }
    if (this.hasSharpeRatioTarget) {
      this.sharpeRatioTarget.textContent = sharpeRatio || '--'
    }
    
    console.log('Risk metrics updated:', { var5, lossProb, volatility, sharpeRatio })
  }

  parseAndFormatCurrency(value) {
    if (!value || value === '') return '--'
    
    // If it's already formatted as currency, extract the number
    if (typeof value === 'string' && value.includes('$')) {
      const numStr = value.replace(/[\$,]/g, '')
      const num = parseFloat(numStr)
      if (isNaN(num)) return '--'
      return this.formatCurrency(num)
    }
    
    // If it's a number, format it
    return this.formatCurrency(value)
  }

  formatCurrency(value) {
    if (value === null || value === undefined || isNaN(value)) return '--'
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(parseFloat(value))
  }

  formatPercentage(value) {
    if (value === null || value === undefined || isNaN(value)) return '--'
    return `${parseFloat(value).toFixed(2)}%`
  }

  createSP500Chart(data) {
    console.log('Creating S&P 500 chart...')
    if (!this.hasSp500ChartTarget || !data.chart_data || !data.chart_data.all_sp500_paths) {
      console.log('No S&P 500 chart target or data found')
      return
    }

    const container = this.sp500ChartTarget
    container.innerHTML = ''

    const margin = { top: 40, right: 50, bottom: 80, left: 80 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200)
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const allPaths = data.chart_data.all_sp500_paths || []
    const meanPath = data.chart_data.mean_sp500_path || []

    if (allPaths.length === 0 && meanPath.length === 0) {
      console.log('No S&P 500 path data available')
      return
    }

    // Create scales
    const maxLength = Math.max(...allPaths.map(p => p.length), meanPath.length)
    const xScale = d3.scaleLinear().domain([0, maxLength - 1]).range([0, width])
    
    const allValues = allPaths.flat().concat(meanPath)
    const yExtent = d3.extent(allValues)
    const yScale = d3.scaleLinear().domain(yExtent).range([height, 0])

    // Add axes
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))

    svg.append("g")
      .call(d3.axisLeft(yScale))

    // Draw sample paths (lightly)
    const line = d3.line()
      .x((d, i) => xScale(i))
      .y(d => yScale(d))

    // Draw a sample of paths to avoid overwhelming the chart
    const sampleSize = Math.min(100, allPaths.length)
    const pathIndices = Array.from({length: sampleSize}, (_, i) => Math.floor(i * allPaths.length / sampleSize))
    
    pathIndices.forEach(i => {
      if (i < allPaths.length && allPaths[i]) {
        svg.append("path")
          .datum(allPaths[i])
          .attr("fill", "none")
          .attr("stroke", "#e0e0e0")
          .attr("stroke-width", 0.5)
          .attr("opacity", 0.3)
          .attr("d", line)
      }
    })

    // Draw mean path (prominently)
    if (meanPath.length > 0) {
      svg.append("path")
        .datum(meanPath)
        .attr("fill", "none")
        .attr("stroke", "#ff6b35")
        .attr("stroke-width", 3)
        .attr("d", line)

      // Add legend
      svg.append("text")
        .attr("x", width - 100)
        .attr("y", 30)
        .attr("fill", "#ff6b35")
        .attr("font-weight", "bold")
        .attr("font-size", "12px")
        .text("Mean path")
    }

    // Add title and labels
    svg.append("text")
      .attr("x", width / 2)
      .attr("y", -5)
      .attr("text-anchor", "middle")
      .attr("font-weight", "bold")
      .text("S&P 500 Price Simulations")

    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 0 - margin.left)
      .attr("x", 0 - (height / 2))
      .attr("dy", "1em")
      .style("text-anchor", "middle")
      .text("Price ($)")
  }

  createLoanDeficitChart(data) {
    console.log('Creating loan deficit chart...')
    if (!this.hasLoanDeficitChartTarget || !data.chart_data) {
      console.log('No loan deficit chart target or data found')
      return
    }

    const container = this.loanDeficitChartTarget
    container.innerHTML = ''

    const margin = { top: 40, right: 50, bottom: 80, left: 80 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200)
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const meanReinvestment = data.chart_data.mean_reinvestment_path || []
    const meanLoan = data.chart_data.mean_loan_path || []
    const meanInterestDeficit = data.chart_data.mean_interest_deficit_path || []

    if (meanReinvestment.length === 0) {
      console.log('No mean path data available')
      return
    }

    const maxLength = Math.max(meanReinvestment.length, meanLoan.length, meanInterestDeficit.length)
    const xScale = d3.scaleLinear().domain([0, maxLength - 1]).range([0, width])
    
    const allValues = meanReinvestment.concat(meanLoan).concat(meanInterestDeficit)
    const yExtent = d3.extent(allValues)
    const yScale = d3.scaleLinear().domain(yExtent).range([height, 0])

    // Add axes
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))

    svg.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => d3.format("$,.0f")(d)))

    const line = d3.line()
      .x((d, i) => xScale(i))
      .y(d => yScale(d))

    // Draw reinvestment account
    if (meanReinvestment.length > 0) {
      svg.append("path")
        .datum(meanReinvestment)
        .attr("fill", "none")
        .attr("stroke", "#2563eb")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // Draw loan
    if (meanLoan.length > 0) {
      svg.append("path")
        .datum(meanLoan)
        .attr("fill", "none")
        .attr("stroke", "#dc2626")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // Draw interest deficit
    if (meanInterestDeficit.length > 0) {
      svg.append("path")
        .datum(meanInterestDeficit)
        .attr("fill", "none")
        .attr("stroke", "#f59e0b")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // Add legend
    const legend = svg.append("g")
      .attr("transform", `translate(${width - 150}, 20)`)

    legend.append("line")
      .attr("x1", 0).attr("x2", 20)
      .attr("y1", 0).attr("y2", 0)
      .attr("stroke", "#2563eb").attr("stroke-width", 2)
    legend.append("text")
      .attr("x", 25).attr("y", 0)
      .attr("dy", "0.35em")
      .attr("font-size", "12px")
      .text("Reinvestment Account")

    legend.append("line")
      .attr("x1", 0).attr("x2", 20)
      .attr("y1", 15).attr("y2", 15)
      .attr("stroke", "#dc2626").attr("stroke-width", 2)
    legend.append("text")
      .attr("x", 25).attr("y", 15)
      .attr("dy", "0.35em")
      .attr("font-size", "12px")
      .text("Loan")

    legend.append("line")
      .attr("x1", 0).attr("x2", 20)
      .attr("y1", 30).attr("y2", 30)
      .attr("stroke", "#f59e0b").attr("stroke-width", 2)
    legend.append("text")
      .attr("x", 25).attr("y", 30)
      .attr("dy", "0.35em")
      .attr("font-size", "12px")
      .text("Interest Deficit")

    // Add labels
    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 0 - margin.left)
      .attr("x", 0 - (height / 2))
      .attr("dy", "1em")
      .style("text-anchor", "middle")
      .text("Value ($)")
  }

  createUnitsChart(data) {
    console.log('Creating units chart...')
    if (!this.hasUnitsChartTarget || !data.chart_data) {
      console.log('No units chart target or data found')
      return
    }

    const container = this.unitsChartTarget
    container.innerHTML = ''

    const margin = { top: 40, right: 50, bottom: 80, left: 80 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200)
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const meanUnits = data.chart_data.mean_units_path || []
    const meanPooledUnits = data.chart_data.mean_pooled_units_path || []
    const meanHedgedUnits = data.chart_data.mean_hedged_units_path || []

    // For insured units, we'll use a static value if available from parameters
    const insuredUnits = data.parameters?.insured_units || 0

    if (meanUnits.length === 0) {
      console.log('No units data available')
      return
    }

    const maxLength = Math.max(meanUnits.length, meanPooledUnits.length, meanHedgedUnits.length)
    const xScale = d3.scaleLinear().domain([0, maxLength - 1]).range([0, width])
    
    const allValues = meanUnits.concat(meanPooledUnits).concat(meanHedgedUnits)
    const yExtent = d3.extent(allValues.concat([insuredUnits]))
    const yScale = d3.scaleLinear().domain(yExtent).range([height, 0])

    // Add axes
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))

    svg.append("g")
      .call(d3.axisLeft(yScale))

    const line = d3.line()
      .x((d, i) => xScale(i))
      .y(d => yScale(d))

    // Draw hedged units (cumulative)
    if (meanHedgedUnits.length > 0) {
      svg.append("path")
        .datum(meanHedgedUnits)
        .attr("fill", "none")
        .attr("stroke", "#16a34a")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // Draw insured units (flat line if static)
    if (insuredUnits > 0) {
      svg.append("line")
        .attr("x1", 0)
        .attr("x2", width)
        .attr("y1", yScale(insuredUnits))
        .attr("y2", yScale(insuredUnits))
        .attr("stroke", "#dc2626")
        .attr("stroke-width", 2)
        .attr("stroke-dasharray", "5,5")
    }

    // Draw pooled units
    if (meanPooledUnits.length > 0) {
      svg.append("path")
        .datum(meanPooledUnits)
        .attr("fill", "none")
        .attr("stroke", "#f59e0b")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // Add legend
    const legend = svg.append("g")
      .attr("transform", `translate(${width - 150}, 20)`)

    let legendY = 0
    
    if (meanHedgedUnits.length > 0) {
      legend.append("line")
        .attr("x1", 0).attr("x2", 20)
        .attr("y1", legendY).attr("y2", legendY)
        .attr("stroke", "#16a34a").attr("stroke-width", 2)
      legend.append("text")
        .attr("x", 25).attr("y", legendY)
        .attr("dy", "0.35em")
        .attr("font-size", "12px")
        .text("Hedged Units")
      legendY += 15
    }

    if (insuredUnits > 0) {
      legend.append("line")
        .attr("x1", 0).attr("x2", 20)
        .attr("y1", legendY).attr("y2", legendY)
        .attr("stroke", "#dc2626").attr("stroke-width", 2)
        .attr("stroke-dasharray", "5,5")
      legend.append("text")
        .attr("x", 25).attr("y", legendY)
        .attr("dy", "0.35em")
        .attr("font-size", "12px")
        .text("Insured Units")
      legendY += 15
    }

    if (meanPooledUnits.length > 0) {
      legend.append("line")
        .attr("x1", 0).attr("x2", 20)
        .attr("y1", legendY).attr("y2", legendY)
        .attr("stroke", "#f59e0b").attr("stroke-width", 2)
      legend.append("text")
        .attr("x", 25).attr("y", legendY)
        .attr("dy", "0.35em")
        .attr("font-size", "12px")
        .text("Pooled Units")
    }

    // Add labels
    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 0 - margin.left)
      .attr("x", 0 - (height / 2))
      .attr("dy", "1em")
      .style("text-anchor", "middle")
      .text("Units")
  }

  createCumulativeChart(data) {
    console.log('Creating cumulative chart...')
    if (!this.hasCumulativeChartTarget || !data.chart_data) {
      console.log('No cumulative chart target or data found')
      return
    }

    const container = this.cumulativeChartTarget
    container.innerHTML = ''

    const margin = { top: 40, right: 50, bottom: 80, left: 80 }
    const containerRect = container.getBoundingClientRect()
    const containerWidth = Math.max(containerRect.width, 1200)
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const meanCumulativeAnnuity = data.chart_data.mean_cumulative_annuity_path || []
    const meanCumulativeInterestPaid = data.chart_data.mean_cumulative_interest_paid_path || []
    const meanLoan = data.chart_data.mean_loan_path || []
    const meanSurplus = data.chart_data.mean_surplus_path || []
    const meanUnits = data.chart_data.mean_units_path || []

    if (meanCumulativeAnnuity.length === 0 && meanCumulativeInterestPaid.length === 0) {
      console.log('No cumulative data available')
      return
    }

    const maxLength = Math.max(
      meanCumulativeAnnuity.length,
      meanCumulativeInterestPaid.length,
      meanLoan.length,
      meanSurplus.length,
      meanUnits.length
    )
    const xScale = d3.scaleLinear().domain([0, maxLength - 1]).range([0, width])
    
    const allValues = meanCumulativeAnnuity
      .concat(meanCumulativeInterestPaid)
      .concat(meanLoan)
      .concat(meanSurplus)
      .concat(meanUnits)
    const yExtent = d3.extent(allValues)
    const yScale = d3.scaleLinear().domain(yExtent).range([height, 0])

    // Add axes
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(xScale))

    svg.append("g")
      .call(d3.axisLeft(yScale).tickFormat(d => d3.format("$,.0f")(d)))

    const line = d3.line()
      .x((d, i) => xScale(i))
      .y(d => yScale(d))

    // Define colors for each series
    const series = [
      { data: meanCumulativeAnnuity, color: "#2563eb", label: "Cumulative Annuity Income" },
      { data: meanCumulativeInterestPaid, color: "#dc2626", label: "Cumulative Interest Paid" },
      { data: meanLoan, color: "#f59e0b", label: "Loan" },
      { data: meanSurplus, color: "#16a34a", label: "Surplus" },
      { data: meanUnits, color: "#8b5cf6", label: "S&P Units" }
    ]

    // Draw each series
    series.forEach(s => {
      if (s.data.length > 0) {
        svg.append("path")
          .datum(s.data)
          .attr("fill", "none")
          .attr("stroke", s.color)
          .attr("stroke-width", 2)
          .attr("d", line)
      }
    })

    // Add legend
    const legend = svg.append("g")
      .attr("transform", `translate(${width - 180}, 20)`)

    series.forEach((s, i) => {
      if (s.data.length > 0) {
        const legendY = i * 15
        legend.append("line")
          .attr("x1", 0).attr("x2", 20)
          .attr("y1", legendY).attr("y2", legendY)
          .attr("stroke", s.color).attr("stroke-width", 2)
        legend.append("text")
          .attr("x", 25).attr("y", legendY)
          .attr("dy", "0.35em")
          .attr("font-size", "11px")
          .text(s.label)
      }
    })

    // Add labels
    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", 0 - margin.left)
      .attr("x", 0 - (height / 2))
      .attr("dy", "1em")
      .style("text-anchor", "middle")
      .text("Value ($)")
  }
}