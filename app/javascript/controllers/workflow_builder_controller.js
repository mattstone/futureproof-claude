import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "palette", "properties", "form"]
  static values = { 
    workflowData: String,
    emailTemplates: Array
  }

  connect() {
    console.log("Enhanced Workflow Builder connected at", new Date().toISOString())
    this.nodes = []
    this.connections = []
    this.selectedNode = null
    this.canvasRect = null
    this.draggedElement = null
    this.isDraggingNode = false
    this.dragOffset = { x: 0, y: 0 }
    this.gridSize = 20
    this.connectingFrom = null
    this.nextNodeId = 1
    
    // Zoom and pan functionality
    this.zoomLevel = 1.0
    this.minZoom = 0.25
    this.maxZoom = 3.0
    this.panOffset = { x: 0, y: 0 }
    
    // Canvas panning state
    this.isPanning = false
    this.panStart = { x: 0, y: 0 }
    this.panStartOffset = { x: 0, y: 0 }
    
    // Panel collapse state
    this.leftPanelCollapsed = false
    this.rightPanelCollapsed = false
    
    this.initCanvas()
    this.createSVGLayer() // Create SVG layer early for faster rendering
    this.initPalette()
    this.initZoomAndPan()
    
    // Load existing workflow immediately
    console.log("About to load existing workflow at", new Date().toISOString())
    this.loadExistingWorkflow()
    console.log("Finished loading existing workflow at", new Date().toISOString())
    this.hideCanvasHint() // Hide hint immediately after trigger appears
    
    // Add window resize listener to update connections when layout changes
    this.resizeHandler = () => {
      // Debounce resize events to avoid excessive redraws
      clearTimeout(this.resizeTimeout)
      this.resizeTimeout = setTimeout(() => {
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      }, 150) // Short delay to allow layout to settle
    }
    window.addEventListener('resize', this.resizeHandler)
    
    // Add a mutation observer to detect layout changes
    this.layoutObserver = new MutationObserver(() => {
      clearTimeout(this.layoutTimeout)
      this.layoutTimeout = setTimeout(() => {
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      }, 200)
    })
    
    // Observe the workspace for class changes (panel collapse/expand)
    const workspace = document.querySelector('.builder-workspace')
    if (workspace) {
      this.layoutObserver.observe(workspace, {
        attributes: true,
        attributeFilter: ['class']
      })
    }
  }

  initCanvas() {
    this.canvasRect = this.canvasTarget.getBoundingClientRect()
    this.canvasTarget.addEventListener('dragover', this.handleCanvasDragOver.bind(this))
    this.canvasTarget.addEventListener('drop', this.handleCanvasDrop.bind(this))
    this.canvasTarget.addEventListener('click', this.handleCanvasClick.bind(this))
    this.canvasTarget.addEventListener('mousedown', this.handleMouseDown.bind(this))
    this.canvasTarget.addEventListener('mousemove', this.handleMouseMove.bind(this))
    this.canvasTarget.addEventListener('mouseup', this.handleMouseUp.bind(this))
    
    // Make canvas relative positioned for absolute positioning of nodes
    this.canvasTarget.style.position = 'relative'
  }

  initPalette() {
    const paletteItems = this.paletteTarget.querySelectorAll('.palette-item')
    paletteItems.forEach(item => {
      item.draggable = true
      item.addEventListener('dragstart', this.handlePaletteDragStart.bind(this))
    })
  }

  createSVGLayer() {
    // Create SVG layer for connections
    this.svgLayer = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    this.svgLayer.style.position = 'absolute'
    this.svgLayer.style.top = '0'
    this.svgLayer.style.left = '0'
    this.svgLayer.style.width = '100%'
    this.svgLayer.style.height = '100%'
    this.svgLayer.style.pointerEvents = 'none'
    this.svgLayer.style.zIndex = '1'
    
    const canvasContent = this.canvasTarget.querySelector('.canvas-content')
    if (canvasContent) {
      canvasContent.appendChild(this.svgLayer)
    } else {
      this.canvasTarget.appendChild(this.svgLayer)
    }

    // Add arrowhead marker
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
    const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker')
    marker.setAttribute('id', 'arrowhead')
    marker.setAttribute('markerWidth', '10')
    marker.setAttribute('markerHeight', '7')
    marker.setAttribute('refX', '9')
    marker.setAttribute('refY', '3.5')
    marker.setAttribute('orient', 'auto')
    
    const polygon = document.createElementNS('http://www.w3.org/2000/svg', 'polygon')
    polygon.setAttribute('points', '0 0, 10 3.5, 0 7')
    polygon.setAttribute('fill', '#6366f1')
    
    marker.appendChild(polygon)
    defs.appendChild(marker)
    this.svgLayer.appendChild(defs)
  }

  handlePaletteDragStart(event) {
    this.draggedElement = {
      type: event.target.dataset.nodeType,
      element: event.target
    }
    event.dataTransfer.effectAllowed = 'copy'
  }

  handleCanvasDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }

  handleCanvasDrop(event) {
    event.preventDefault()
    if (!this.draggedElement) return

    console.log(`handleCanvasDrop: Using smart positioning for ${this.draggedElement.type}`)
    // Use smart positioning instead of drop coordinates
    const smartPosition = this.getSmartNodePosition(this.draggedElement.type)
    
    this.createNode(this.draggedElement.type, smartPosition.x, smartPosition.y)
    this.draggedElement = null
  }

  handleMouseDown(event) {
    const nodeElement = event.target.closest('.workflow-node')
    if (nodeElement && !event.target.closest('.node-delete, .connection-point')) {
      this.isDraggingNode = true
      this.draggedNodeId = nodeElement.dataset.nodeId
      
      const rect = this.canvasTarget.getBoundingClientRect()
      const nodeRect = nodeElement.getBoundingClientRect()
      this.dragOffset = {
        x: event.clientX - nodeRect.left,
        y: event.clientY - nodeRect.top
      }
      
      nodeElement.style.zIndex = '1000'
      event.preventDefault()
    }

    // Handle connection point clicks
    const connectionPoint = event.target.closest('.connection-point')
    if (connectionPoint) {
      const nodeElement = connectionPoint.closest('.workflow-node')
      const nodeId = nodeElement.dataset.nodeId
      const isOutput = connectionPoint.classList.contains('output-point')
      
      this.handleConnectionPoint(nodeId, isOutput, event)
      event.stopPropagation()
      return
    }
    
    // Handle canvas panning - only if clicking on empty canvas area
    if (event.target === this.canvasTarget || event.target.closest('.canvas-content')) {
      this.isPanning = true
      this.panStart = { x: event.clientX, y: event.clientY }
      this.panStartOffset = { x: this.panOffset.x, y: this.panOffset.y }
      this.canvasTarget.style.cursor = 'grabbing'
      event.preventDefault()
    }
  }

  handleMouseMove(event) {
    if (this.isDraggingNode && this.draggedNodeId) {
      const rect = this.canvasTarget.getBoundingClientRect()
      const x = this.snapToGrid(event.clientX - rect.left - this.dragOffset.x)
      const y = this.snapToGrid(event.clientY - rect.top - this.dragOffset.y)
      
      // Update node position
      const nodeElement = document.querySelector(`[data-node-id="${this.draggedNodeId}"]`)
      if (nodeElement) {
        nodeElement.style.left = `${x}px`
        nodeElement.style.top = `${y}px`
        
        // Update node data
        const node = this.nodes.find(n => n.id == this.draggedNodeId)
        if (node) {
          node.x = x
          node.y = y
          node.gridX = Math.floor(x / this.gridSize)
          node.gridY = Math.floor(y / this.gridSize)
        }
        
        // Redraw connections
        this.redrawConnections()
      }
    } else if (this.isPanning) {
      // Handle canvas panning
      const dx = event.clientX - this.panStart.x
      const dy = event.clientY - this.panStart.y
      
      this.panOffset.x = this.panStartOffset.x + dx
      this.panOffset.y = this.panStartOffset.y + dy
      
      this.applyTransform()
    }
  }

  handleMouseUp(event) {
    if (this.isDraggingNode) {
      const nodeElement = document.querySelector(`[data-node-id="${this.draggedNodeId}"]`)
      if (nodeElement) {
        nodeElement.style.zIndex = '10'
      }
      this.isDraggingNode = false
      this.draggedNodeId = null
      this.updateFormData()
    }
    
    if (this.isPanning) {
      this.isPanning = false
      this.canvasTarget.style.cursor = 'default'
    }
  }

  handleConnectionPoint(nodeId, isOutput, event) {
    if (this.connectingFrom === null) {
      // Start connecting
      if (isOutput) {
        this.connectingFrom = nodeId
        this.showConnectionFeedback(nodeId, true)
      }
    } else {
      // Complete connection
      if (!isOutput && this.connectingFrom != nodeId) {
        this.createConnection(this.connectingFrom, nodeId)
      }
      this.clearConnectionFeedback()
      this.connectingFrom = null
    }
  }

  showConnectionFeedback(nodeId, connecting) {
    const nodeElement = document.querySelector(`[data-node-id="${nodeId}"]`)
    if (nodeElement) {
      if (connecting) {
        nodeElement.classList.add('connecting-from')
        // Highlight valid targets
        this.nodes.forEach(node => {
          if (node.id != nodeId) {
            const targetElement = document.querySelector(`[data-node-id="${node.id}"]`)
            targetElement?.classList.add('connection-target')
          }
        })
      } else {
        nodeElement.classList.remove('connecting-from', 'connection-target')
      }
    }
  }

  clearConnectionFeedback() {
    document.querySelectorAll('.workflow-node').forEach(node => {
      node.classList.remove('connecting-from', 'connection-target')
    })
  }

  snapToGrid(value) {
    return Math.round(value / this.gridSize) * this.gridSize
  }

  createNode(type, x, y, skipAutoSetup = false) {
    const nodeId = this.nextNodeId++
    
    // Auto-position if coordinates would overlap
    const adjustedPosition = this.findAvailablePosition(x, y)
    
    const node = {
      id: nodeId,
      type: type,
      x: adjustedPosition.x,
      y: adjustedPosition.y,
      gridX: Math.floor(adjustedPosition.x / this.gridSize),
      gridY: Math.floor(adjustedPosition.y / this.gridSize),
      config: this.getDefaultNodeConfig(type),
      connections: []
    }
    
    this.nodes.push(node)
    this.renderNode(node)
    
      // Auto-connect to previous node first (before creating branches)
    if (!skipAutoSetup && type !== 'branch') {
      this.autoConnectToChain(node)
    }
    
    // Then create condition branches if needed
    if (type === 'condition' && !skipAutoSetup) {
      // Set has_branches BEFORE creating endpoints so connection points render correctly
      node.config.has_branches = true
      this.createConditionEndpoints(node)
    } else if (type === 'branch' && !skipAutoSetup) {
      // Branch nodes should not auto-connect as they are created by condition nodes
      // They can be manually connected to continue the workflow
    }
    
    this.updateFormData()
    this.hideCanvasHint()
    return node
  }

  getSmartNodePosition(nodeType) {
    // Smart positioning rules to keep workflow organized
    const nodeWidth = 200
    const nodeHeight = 100
    const verticalSpacing = 140 // Space between vertical levels
    const horizontalSpacing = 260 // Space for branches
    
    // Find the trigger node as our reference point
    const triggerNode = this.nodes.find(node => node.type === 'trigger')
    if (!triggerNode) {
      // If no trigger, place at default position
      console.log('No trigger found, using default position')
      return { x: 100, y: 100 }
    }
    
    console.log(`getSmartNodePosition for ${nodeType}: trigger at (${triggerNode.x}, ${triggerNode.y})`)
    
    // Count non-branch, non-trigger nodes to determine main chain position
    const mainChainNodes = this.nodes.filter(node => 
      node.type !== 'trigger' && node.type !== 'branch'
    )
    
    console.log(`mainChainNodes.length: ${mainChainNodes.length}`)
    
    if (nodeType === 'branch') {
      // Branches are positioned by createConditionEndpoints, not here
      const pos = { x: triggerNode.x + horizontalSpacing, y: triggerNode.y }
      console.log(`Branch position: (${pos.x}, ${pos.y})`)
      return this.findAvailablePosition(pos.x, pos.y)
    }
    
    // Main chain nodes go directly under trigger with vertical spacing
    const chainLevel = mainChainNodes.length // Don't add 1 - this IS the next node
    const targetX = triggerNode.x // Same X as trigger
    const targetY = triggerNode.y + verticalSpacing + (verticalSpacing * chainLevel)
    
    console.log(`Smart position calculation: chainLevel=${chainLevel}, targetX=${targetX}, targetY=${targetY}`)
    
    // Check if position is available, if not, find nearby spot
    return this.findAvailablePosition(targetX, targetY)
  }
  
  findAvailablePosition(x, y) {
    const nodeWidth = 200
    const nodeHeight = 100
    const margin = 20
    
    let testX = x
    let testY = y
    let attempts = 0
    
    console.log(`findAvailablePosition: Checking position (${x}, ${y})`)
    
    while (attempts < 50) {
      const hasOverlap = this.nodes.some(node => {
        const xOverlap = Math.abs(node.x - testX) < nodeWidth + margin
        const yOverlap = Math.abs(node.y - testY) < nodeHeight + margin
        const overlap = xOverlap && yOverlap
        
        if (overlap) {
          console.log(`  Overlap detected with ${node.type} at (${node.x}, ${node.y}):`)
          console.log(`    X distance: ${Math.abs(node.x - testX)} < ${nodeWidth + margin} = ${xOverlap}`)
          console.log(`    Y distance: ${Math.abs(node.y - testY)} < ${nodeHeight + margin} = ${yOverlap}`)
        }
        
        return overlap
      })
      
      if (!hasOverlap) {
        console.log(`  Final position: (${testX}, ${testY})`)
        return { x: testX, y: testY }
      }
      
      // Try positions in order of preference: below, right, left
      if (attempts < 10) {
        testY += 140 // Try below first (vertical spacing)
      } else if (attempts < 25) {
        testX += nodeWidth + margin // Then try to the right
        testY = y // Reset Y
      } else {
        testX -= nodeWidth + margin // Then try to the left
        testY = y // Reset Y
      }
      
      attempts++
    }
    
    return { x: testX, y: testY }
  }

  autoConnectToChain(newNode) {
    if (this.nodes.length <= 1) return
    
    // For the main chain: find the last node without outgoing connections that isn't a condition with branches
    const chainNodes = this.nodes.filter(node => {
      return node.id != newNode.id && 
             node.type !== 'branch' && // Exclude branch nodes from main chain
             !this.connections.some(conn => conn.from == node.id) &&
             !(node.type === 'condition' && node.config.has_branches)
    })
    
    // If we found a node to connect to in the main chain, connect it
    if (chainNodes.length > 0) {
      const lastChainNode = chainNodes[chainNodes.length - 1]
      console.log(`Auto-connecting ${lastChainNode.type} (id: ${lastChainNode.id}) to ${newNode.type} (id: ${newNode.id})`)
      this.createConnection(lastChainNode.id, newNode.id)
    }
  }

  createConnection(fromNodeId, toNodeId, label = null) {
    // Prevent duplicate connections
    const existingConnection = this.connections.find(conn => 
      conn.from == fromNodeId && conn.to == toNodeId
    )
    if (existingConnection) return

    const connection = {
      id: `conn_${Date.now()}`,
      from: fromNodeId,
      to: toNodeId,
      label: label
    }
    
    this.connections.push(connection)
    this.drawConnection(connection)
    this.updateFormData()
  }

  drawConnection(connection) {
    const fromNode = this.nodes.find(n => n.id == connection.from)
    const toNode = this.nodes.find(n => n.id == connection.to)
    
    if (!fromNode || !toNode) return

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('class', 'connection-path')
    path.setAttribute('data-connection-id', connection.id)
    
    // Set color and style based on connection label
    if (connection.label === 'yes') {
      path.setAttribute('stroke', '#10b981')
      path.setAttribute('stroke-width', '2.5')
      path.setAttribute('data-connection-label', 'yes')
    } else if (connection.label === 'no') {
      path.setAttribute('stroke', '#ef4444')
      path.setAttribute('stroke-width', '2.5')
      path.setAttribute('data-connection-label', 'no')
    } else {
      path.setAttribute('stroke', '#6366f1')
      path.setAttribute('stroke-width', '2')
    }
    
    path.setAttribute('fill', 'none')
    // Removed arrow heads for cleaner look
    
    this.updateConnectionPath(path, fromNode, toNode)
    this.svgLayer.appendChild(path)
    
    // Add connection label if it exists
    if (connection.label && (connection.label === 'yes' || connection.label === 'no')) {
      this.addConnectionLabel(connection, fromNode, toNode)
    }
    
    // Add click handler for connection deletion
    path.style.pointerEvents = 'stroke'
    path.style.cursor = 'pointer'
    path.addEventListener('dblclick', () => this.deleteConnection(connection.id))
  }

  updateConnectionPath(path, fromNode, toNode) {
    // Get actual node elements to calculate real dimensions
    const fromElement = document.querySelector(`[data-node-id="${fromNode.id}"]`)
    const toElement = document.querySelector(`[data-node-id="${toNode.id}"]`)
    
    if (!fromElement || !toElement) return
    
    // Force a layout update to ensure positions are current
    fromElement.offsetHeight
    toElement.offsetHeight
    
    // Get fresh canvas rect after any layout changes
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const canvasContent = this.canvasTarget.querySelector('.canvas-content')
    const contentRect = canvasContent ? canvasContent.getBoundingClientRect() : canvasRect
    
    // Get node positions relative to the canvas content (not the canvas container)
    const fromRect = fromElement.getBoundingClientRect()
    const toRect = toElement.getBoundingClientRect()
    
    // Calculate positions relative to canvas content, accounting for zoom and pan
    let startX, startY
    
    // Check if this is a conditional branch connection
    const connection = this.connections.find(conn => 
      conn.from == fromNode.id && conn.to == toNode.id
    )
    
    // Special handling for diamond-shaped condition nodes
    if (fromNode.type === 'condition') {
      const centerX = fromRect.left + fromRect.width / 2 - contentRect.left
      const centerY = fromRect.top + fromRect.height / 2 - contentRect.top
      
      // Use fixed offsets - getBoundingClientRect already accounts for zoom
      const diamondHalfWidth = 50
      const diamondHalfHeight = 30
      
      if (connection && connection.label === 'yes') {
        // Yes path from right edge of diamond
        startX = centerX + diamondHalfWidth
        startY = centerY
      } else if (connection && connection.label === 'no') {
        // No path from left edge of diamond
        startX = centerX - diamondHalfWidth
        startY = centerY
      } else {
        // Regular connection from top of diamond
        startX = centerX
        startY = centerY - diamondHalfHeight
      }
    } else {
      // Regular node connections
      if (connection && connection.label === 'yes') {
        // Yes path from right connection point
        startX = (fromRect.right - contentRect.left)
        startY = (fromRect.top + fromRect.height / 2 - contentRect.top)
      } else if (connection && connection.label === 'no') {
        // No path from left connection point
        startX = (fromRect.left - contentRect.left)
        startY = (fromRect.top + fromRect.height / 2 - contentRect.top)
      } else {
        // Regular connection from center bottom for vertical connections
        startX = (fromRect.left + fromRect.width / 2 - contentRect.left)
        startY = (fromRect.bottom - contentRect.top)
      }
    }
    
    const endX = (toRect.left + toRect.width / 2 - contentRect.left)
    const endY = (toRect.top - contentRect.top)
    
    // Create Klaviyo-style right-angled path (horizontal then vertical)
    let pathData
    
    if (connection && (connection.label === 'yes' || connection.label === 'no')) {
      // For conditional branches: small horizontal extension then straight down to center
      const horizontalExtension = connection.label === 'yes' ? 80 : -80 // Fixed extension - getBoundingClientRect handles zoom
      const midX = startX + horizontalExtension
      
      // Only 2 lines: horizontal extension, then straight down to center of target node
      pathData = `M ${startX} ${startY} L ${midX} ${startY} L ${midX} ${endY}`
    } else {
      // For regular connections: straight line
      pathData = `M ${startX} ${startY} L ${endX} ${endY}`
    }
    
    path.setAttribute('d', pathData)
    
    console.log(`Updated connection: ${connection?.label || 'regular'} from (${startX},${startY}) to (${endX},${endY})`)
  }

  redrawConnections() {
    this.connections.forEach(connection => {
      const pathElement = this.svgLayer.querySelector(`[data-connection-id="${connection.id}"]`)
      const labelElement = this.svgLayer.querySelector(`.connection-label[data-connection-id="${connection.id}"]`)
      const fromNode = this.nodes.find(n => n.id == connection.from)
      const toNode = this.nodes.find(n => n.id == connection.to)
      
      if (pathElement && fromNode && toNode) {
        this.updateConnectionPath(pathElement, fromNode, toNode)
        
        // Update label position if it exists
        if (labelElement && connection.label) {
          const fromElement = document.querySelector(`[data-node-id="${fromNode.id}"]`)
          if (fromElement) {
            const fromRect = fromElement.getBoundingClientRect()
            const canvasRect = this.canvasTarget.getBoundingClientRect()
            
            let labelX, labelY
            const canvasContent = this.canvasTarget.querySelector('.canvas-content')
            const contentRect = canvasContent ? canvasContent.getBoundingClientRect() : canvasRect
            
            // Special label positioning for diamond condition nodes
            if (fromNode.type === 'condition') {
              const centerX = fromRect.left + fromRect.width / 2 - contentRect.left
              const centerY = fromRect.top + fromRect.height / 2 - contentRect.top
              
              if (connection.label === 'yes') {
                labelX = centerX + 80 // Right side of diamond + offset
                labelY = centerY - 10
              } else {
                labelX = centerX - 80 // Left side of diamond + offset
                labelY = centerY - 10
              }
            } else {
              // Regular node label positioning
              if (connection.label === 'yes') {
                labelX = (fromRect.right + 20 - contentRect.left)
                labelY = (fromRect.top + fromRect.height / 2 - contentRect.top)
              } else {
                labelX = (fromRect.left - 20 - contentRect.left)
                labelY = (fromRect.top + fromRect.height / 2 - contentRect.top)
              }
            }
            
            labelElement.setAttribute('x', labelX)
            labelElement.setAttribute('y', labelY)
          }
        }
      }
    })
  }

  addConnectionLabel(connection, fromNode, toNode) {
    const labelElement = document.createElementNS('http://www.w3.org/2000/svg', 'text')
    labelElement.setAttribute('class', 'connection-label')
    labelElement.setAttribute('data-connection-id', connection.id)
    labelElement.setAttribute('font-size', '12')
    labelElement.setAttribute('font-weight', 'bold')
    labelElement.setAttribute('text-anchor', 'middle')
    labelElement.setAttribute('dominant-baseline', 'middle')
    
    // Set label color and text
    if (connection.label === 'yes') {
      labelElement.setAttribute('fill', '#059669')
      labelElement.textContent = 'YES'
    } else if (connection.label === 'no') {
      labelElement.setAttribute('fill', '#dc2626')
      labelElement.textContent = 'NO'
    }
    
    // Position label at the start of the connection
    const fromElement = document.querySelector(`[data-node-id="${fromNode.id}"]`)
    if (fromElement) {
      const fromRect = fromElement.getBoundingClientRect()
      const canvasRect = this.canvasTarget.getBoundingClientRect()
      
      let labelX, labelY
      const canvasContent = this.canvasTarget.querySelector('.canvas-content')
      const contentRect = canvasContent ? canvasContent.getBoundingClientRect() : canvasRect
      
      // Special label positioning for diamond condition nodes
      if (fromNode.type === 'condition') {
        const centerX = fromRect.left + fromRect.width / 2 - contentRect.left
        const centerY = fromRect.top + fromRect.height / 2 - contentRect.top
        
        if (connection.label === 'yes') {
          labelX = centerX + 80 // Right side of diamond + offset
          labelY = centerY - 10
        } else {
          labelX = centerX - 80 // Left side of diamond + offset
          labelY = centerY - 10
        }
      } else {
        // Regular node label positioning
        if (connection.label === 'yes') {
          labelX = (fromRect.right + 20 - contentRect.left)
          labelY = (fromRect.top + fromRect.height / 2 - contentRect.top)
        } else {
          labelX = (fromRect.left - 20 - contentRect.left)
          labelY = (fromRect.top + fromRect.height / 2 - contentRect.top)
        }
      }
      
      labelElement.setAttribute('x', labelX)
      labelElement.setAttribute('y', labelY)
    }
    
    this.svgLayer.appendChild(labelElement)
  }

  deleteConnection(connectionId) {
    this.connections = this.connections.filter(conn => conn.id !== connectionId)
    
    // Remove path element
    const pathElement = this.svgLayer.querySelector(`[data-connection-id="${connectionId}"]`)
    if (pathElement) {
      pathElement.remove()
    }
    
    // Remove label element if it exists
    const labelElement = this.svgLayer.querySelector(`.connection-label[data-connection-id="${connectionId}"]`)
    if (labelElement) {
      labelElement.remove()
    }
    
    this.updateFormData()
  }

  getDefaultNodeConfig(type) {
    switch(type) {
      case 'trigger':
        return { trigger_type: '' }
      case 'email':
        return { email_template_id: '' }
      case 'delay':
        return { duration: 1, unit: 'hours' }
      case 'condition':
        return { condition_type: '' }
      case 'update':
        return { field: '', value: '' }
      case 'endpoint':
        return { endpoint_type: 'end', label: 'End' }
      case 'branch':
        return { branch_type: 'condition_branch', label: 'Branch', condition_value: null }
      default:
        return {}
    }
  }

  renderNode(node) {
    console.log(`Rendering ${node.type} node (id: ${node.id}) at`, new Date().toISOString())
    const nodeElement = document.createElement('div')
    nodeElement.className = `workflow-node node-${node.type}`
    nodeElement.dataset.nodeId = node.id
    
    // Add branch type data attribute for styling
    if (node.type === 'branch' && node.config.branch_type) {
      nodeElement.dataset.branchType = node.config.branch_type
    }
    
    nodeElement.style.position = 'absolute'
    nodeElement.style.left = `${node.x}px`
    nodeElement.style.top = `${node.y}px`
    nodeElement.style.zIndex = '10'
    
    // Special rendering for condition nodes (diamond shape)
    if (node.type === 'condition') {
      nodeElement.innerHTML = `
        <div class="node-content">
          ${this.getNodeDescription(node)}
        </div>
        <div class="connection-points">
          <div class="input-point connection-point" title="Input: click to receive connections"></div>
          ${node.config.has_branches ? '<div class="no-output-point connection-point" title="No path"></div><div class="yes-output-point connection-point" title="Yes path"></div>' : '<div class="output-point connection-point" title="Output: click to connect to other nodes"></div>'}
        </div>
        ${node.type !== 'trigger' ? `<button class="node-delete" data-action="click->workflow-builder#deleteNode" data-node-id="${node.id}"><i class="fas fa-times"></i></button>` : ''}
      `
    } else {
      // Regular node rendering
      nodeElement.innerHTML = `
        <div class="node-header">
          <div class="node-icon">
            ${this.getNodeIcon(node.type)}
          </div>
          <span class="node-title">${this.getNodeTitle(node.type)}</span>
          ${node.type !== 'trigger' ? `<button class="node-delete" data-action="click->workflow-builder#deleteNode" data-node-id="${node.id}"><i class="fas fa-times"></i></button>` : ''}
        </div>
        <div class="node-body">
          <div class="node-description">
            ${this.getNodeDescription(node)}
          </div>
        </div>
        <div class="connection-points">
          ${node.type !== 'trigger' ? '<div class="input-point connection-point" title="Input: click to receive connections"></div>' : ''}
          ${(node.type !== 'endpoint' && !(node.type === 'condition' && node.config.has_branches)) ? '<div class="output-point connection-point" title="Output: click to connect to other nodes"></div>' : ''}
        </div>
      `
    }

    // Add click handler for node selection
    nodeElement.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectNode(node)
    })

    const canvasContent = this.canvasTarget.querySelector('.canvas-content')
    if (canvasContent) {
      canvasContent.appendChild(nodeElement)
    } else {
      this.canvasTarget.appendChild(nodeElement)
    }

    // Make the node draggable and add connection handlers
    this.makeNodeDraggable(nodeElement, node)
    this.addConnectionHandlers(nodeElement, node)
  }

  getNodeIcon(type) {
    const icons = {
      trigger: '<i class="fas fa-bolt"></i>',
      email: '<i class="fas fa-envelope"></i>',
      delay: '<i class="fas fa-clock"></i>',
      condition: '<i class="fas fa-code-branch"></i>',
      update: '<i class="fas fa-edit"></i>',
      endpoint: '<i class="fas fa-stop-circle"></i>',
      branch: '<i class="fas fa-arrow-right"></i>'
    }
    return icons[type] || '<i class="fas fa-circle"></i>'
  }

  getNodeTitle(type) {
    const titles = {
      trigger: 'Trigger',
      email: 'Send Email',
      delay: 'Wait',
      condition: 'Condition',
      update: 'Update Status',
      endpoint: 'End',
      branch: 'Branch'
    }
    return titles[type] || 'Node'
  }

  getNodeDescription(node) {
    switch(node.type) {
      case 'trigger':
        if (node.config.trigger_type === 'application_status_changed') {
          if (node.config.from_status && node.config.to_status) {
            const statuses = this.getApplicationStatuses()
            const fromLabel = statuses.find(s => s.key === node.config.from_status)?.label
            const toLabel = statuses.find(s => s.key === node.config.to_status)?.label
            return `App: ${fromLabel} → ${toLabel}`
          } else {
            return 'Configure app status change'
          }
        }
        if (node.config.trigger_type === 'contract_status_changed') {
          if (node.config.contract_from_status && node.config.contract_to_status) {
            const statuses = this.getContractStatuses()
            const fromLabel = statuses.find(s => s.key === node.config.contract_from_status)?.label
            const toLabel = statuses.find(s => s.key === node.config.contract_to_status)?.label
            return `Contract: ${fromLabel} → ${toLabel}`
          } else {
            return 'Configure contract status change'
          }
        }
        return node.config.trigger_type ? node.config.trigger_type.replace('_', ' ').toUpperCase() : 'Select trigger type'
      case 'email':
        if (node.config.email_template_id) {
          const template = this.emailTemplatesValue?.find(t => t.id == node.config.email_template_id)
          return template ? `Send: ${template.name}` : 'Configure email template'
        }
        return 'Configure email template'
      case 'delay':
        return node.config.duration ? `Wait ${node.config.duration} ${node.config.unit || 'minutes'}` : 'Configure delay'
      case 'condition':
        return node.config.condition_type ? 'Check condition' : 'Configure condition'
      case 'update':
        return node.config.field ? `Update ${node.config.field}` : 'Configure update'
      case 'endpoint':
        return node.config.label || 'End'
      case 'branch':
        return node.config.label || 'Branch'
      default:
        return 'Configure node'
    }
  }

  createConditionEndpoints(conditionNode) {
    // Klaviyo-style branch positioning: horizontally aligned at same Y level
    const horizontalExtension = 80 // Distance from center for connection line
    const verticalDrop = 120 // Distance below condition for both branches
    const nodeWidth = 180 // CSS min-width from workflow nodes
    
    // Both branches at same Y level (horizontally aligned like Klaviyo)
    const branchY = conditionNode.y + verticalDrop
    
    // Position branches to align with where connection lines actually drop
    // We need to calculate based on the actual DOM position, not node.x
    
    // Get the actual condition element to find its real center
    const conditionElement = document.querySelector(`[data-node-id="${conditionNode.id}"]`)
    if (!conditionElement) {
      console.error('Could not find condition element for branch positioning')
      return
    }
    
    // Force layout update
    conditionElement.offsetHeight
    
    const canvasContent = this.canvasTarget.querySelector('.canvas-content')
    const contentRect = canvasContent ? canvasContent.getBoundingClientRect() : this.canvasTarget.getBoundingClientRect()
    const conditionRect = conditionElement.getBoundingClientRect()
    
    // Get actual diamond center in canvas coordinates
    const actualDiamondCenterX = conditionRect.left + conditionRect.width / 2 - contentRect.left
    
    console.log('Branch positioning debug:')
    console.log(`  Condition node.x: ${conditionNode.x}`)
    console.log(`  DOM diamond center: ${actualDiamondCenterX}`)
    console.log(`  Difference: ${actualDiamondCenterX - conditionNode.x}`)
    
    // Calculate actual diamond edges  
    const actualDiamondLeftEdgeX = actualDiamondCenterX - 50   // Left edge of diamond
    const actualDiamondRightEdgeX = actualDiamondCenterX + 50  // Right edge of diamond
    
    // Calculate where connection lines will drop (from diamond edges + extension)
    const noLineDropX = actualDiamondLeftEdgeX - horizontalExtension   
    const yesLineDropX = actualDiamondRightEdgeX + horizontalExtension
    
    console.log(`  NO line drop: ${noLineDropX}, YES line drop: ${yesLineDropX}`) 
    
    // Based on actual connection behavior, position branches where they'll actually connect
    // From the logs: connections drop at different points than calculated
    // Let me try a direct approach: position relative to the actual diamond DOM position
    
    const noBranchNodeX = conditionNode.x - 130  // NO connection appears ~50px left of calculated  
    const yesBranchNodeX = conditionNode.x + 50   // YES connection appears ~80px left of calculated
    
    console.log(`  NO branch node coord: ${noBranchNodeX}, YES branch node coord: ${yesBranchNodeX}`)
    console.log('  Testing simplified positioning approach')
    
    const noBranch = this.createNode('branch', noBranchNodeX, branchY, true)
    noBranch.config.label = 'No' 
    noBranch.config.branch_type = 'condition_no'
    noBranch.config.parent_condition = conditionNode.id
    noBranch.config.condition_value = false

    const yesBranch = this.createNode('branch', yesBranchNodeX, branchY, true)
    yesBranch.config.label = 'Yes'
    yesBranch.config.branch_type = 'condition_yes'
    yesBranch.config.parent_condition = conditionNode.id
    yesBranch.config.condition_value = true

    // Auto-connect condition to both branches
    this.createConnection(conditionNode.id, noBranch.id, 'no')
    this.createConnection(conditionNode.id, yesBranch.id, 'yes')

    // Update node descriptions
    this.refreshNodeDisplay(yesBranch)
    this.refreshNodeDisplay(noBranch)
    this.refreshNodeDisplay(conditionNode) // Refresh condition node display
    
    return { yesBranch, noBranch }
  }

  selectNode(node) {
    // Clear previous selection
    document.querySelectorAll('.workflow-node').forEach(n => n.classList.remove('selected'))

    this.selectedNode = node
    
    if (this.selectedNode) {
      const nodeElement = document.querySelector(`[data-node-id="${node.id}"]`)
      nodeElement.classList.add('selected')
      this.showNodeProperties(this.selectedNode)
    }
  }

  makeNodeDraggable(nodeElement, node) {
    let isDragging = false
    let dragStart = { x: 0, y: 0 }
    let nodeStart = { x: 0, y: 0 }

    // Use .node-content for condition nodes, .node-header for others
    const dragHandle = nodeElement.querySelector('.node-header') || nodeElement.querySelector('.node-content') || nodeElement
    
    if (dragHandle.style) {
      dragHandle.style.cursor = 'move'
    }
    
    dragHandle.addEventListener('mousedown', (e) => {
      if (e.target.closest('.node-delete, .connection-point')) return
      
      isDragging = true
      dragStart = { x: e.clientX, y: e.clientY }
      nodeStart = { x: node.x, y: node.y }
      
      nodeElement.style.zIndex = '100'
      nodeElement.classList.add('dragging')
      
      e.preventDefault()
      e.stopPropagation()
    })

    const handleMouseMove = (e) => {
      if (!isDragging) return
      
      const dx = e.clientX - dragStart.x
      const dy = e.clientY - dragStart.y
      
      const newX = nodeStart.x + dx / this.zoomLevel
      const newY = nodeStart.y + dy / this.zoomLevel
      
      // Snap to grid
      const snappedX = Math.round(newX / this.gridSize) * this.gridSize
      const snappedY = Math.round(newY / this.gridSize) * this.gridSize
      
      node.x = snappedX
      node.y = snappedY
      
      nodeElement.style.left = `${snappedX}px`
      nodeElement.style.top = `${snappedY}px`
      
      // Update connections
      this.redrawConnections()
    }

    const handleMouseUp = () => {
      if (isDragging) {
        isDragging = false
        nodeElement.style.zIndex = '10'
        nodeElement.classList.remove('dragging')
        this.updateFormData()
      }
    }

    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)
  }

  addConnectionHandlers(nodeElement, node) {
    const inputPoint = nodeElement.querySelector('.input-point')
    const outputPoint = nodeElement.querySelector('.output-point')
    const yesPoint = nodeElement.querySelector('.yes-output-point')
    const noPoint = nodeElement.querySelector('.no-output-point')

    if (outputPoint) {
      outputPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        
        if (this.connectingFrom) {
          // Complete connection
          if (this.connectingFrom.id !== node.id) {
            this.createConnection(this.connectingFrom.id, node.id)
          }
          this.clearConnectionMode()
        } else {
          // Start connection from this node
          this.startConnectionFrom(node)
        }
      })
    }

    // Handle Yes/No connection points for condition nodes
    if (yesPoint) {
      yesPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        
        if (this.connectingFrom) {
          // Complete connection with Yes label
          if (this.connectingFrom.id !== node.id) {
            this.createConnection(this.connectingFrom.id, node.id, 'yes')
          }
          this.clearConnectionMode()
        } else {
          // Start Yes connection from this condition node
          this.startConnectionFrom(node, 'yes')
        }
      })
    }

    if (noPoint) {
      noPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        
        if (this.connectingFrom) {
          // Complete connection with No label
          if (this.connectingFrom.id !== node.id) {
            this.createConnection(this.connectingFrom.id, node.id, 'no')
          }
          this.clearConnectionMode()
        } else {
          // Start No connection from this condition node
          this.startConnectionFrom(node, 'no')
        }
      })
    }

    if (inputPoint) {
      inputPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        
        if (this.connectingFrom) {
          // Complete connection
          if (this.connectingFrom.id !== node.id) {
            const label = this.connectingFrom.connectionType || null
            this.createConnection(this.connectingFrom.id, node.id, label)
          }
          this.clearConnectionMode()
        }
      })
    }
  }

  startConnectionFrom(node, connectionType = null) {
    this.connectingFrom = node
    this.connectingFrom.connectionType = connectionType // Store connection type (yes/no)
    
    document.querySelectorAll('.workflow-node').forEach(n => n.classList.remove('connecting-from'))
    
    const nodeElement = document.querySelector(`[data-node-id="${node.id}"]`)
    nodeElement.classList.add('connecting-from')
    
    // Visual feedback
    this.canvasTarget.classList.add('connecting-mode')
  }

  clearConnectionMode() {
    if (this.connectingFrom) {
      this.connectingFrom.connectionType = null
    }
    this.connectingFrom = null
    document.querySelectorAll('.workflow-node').forEach(n => n.classList.remove('connecting-from'))
    this.canvasTarget.classList.remove('connecting-mode')
  }




  showNodeProperties(node) {
    // Use server-side rendering via Turbo Frame
    const frame = document.getElementById('node-properties-frame')
    if (!frame) return
    
    // Build URL with node type and config as params
    const params = new URLSearchParams({
      node_type: node.type,
      ...Object.keys(node.config || {}).reduce((acc, key) => {
        acc[`config[${key}]`] = node.config[key]
        return acc
      }, {})
    })
    
    const url = `/admin/email_workflows/node_properties?${params}`
    frame.src = url
    this.propertiesTarget.classList.add('visible')
  }

  renderNodeProperties(node) {
    switch(node.type) {
      case 'trigger':
        return this.getTriggerPropertiesHTML(node)
      case 'email':
        return this.getEmailPropertiesHTML(node)
      case 'delay':
        return this.getDelayPropertiesHTML(node)
      case 'condition':
        return this.getConditionPropertiesHTML(node)
      case 'update':
        return this.getUpdatePropertiesHTML(node)
      default:
        return '<p>Select a node to configure its properties</p>'
    }
  }

  getTriggerPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Trigger Configuration</h3>
      <div class="property-group">
        <p>Configure trigger in the main workflow form above.</p>
      </div>
      
      <div class="connection-info">
        <h6>Connections</h6>
        <p class="text-small">
          <strong>Output:</strong> Click the right circle to connect to other nodes
        </p>
      </div>
    `
  }


  getEmailPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Email Configuration</h3>
      <div class="property-group">
        <label>Email Template</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="email_template_id">
          <option value="">Select template...</option>
          ${this.getEmailTemplateOptions(node.config.email_template_id)}
        </select>
        <p class="field-help">Choose which email template to send</p>
      </div>
      
      <div class="connection-info">
        <h6>Connections</h6>
        <p class="text-small">
          <strong>Input:</strong> Click the left circle to receive connections<br>
          <strong>Output:</strong> Click the right circle to connect to other nodes
        </p>
      </div>
    `
  }

  getDelayPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Delay Configuration</h3>
      <div class="property-group">
        <label>Wait for</label>
        <div class="inline-fields">
          <input type="number" min="1" value="${node.config.duration || ''}" 
                 data-action="input->workflow-builder#updateNodeConfig" data-property="duration"
                 class="duration-input">
          <select data-action="change->workflow-builder#updateNodeConfig" data-property="unit"
                  class="unit-select">
            <option value="minutes" ${node.config.unit === 'minutes' ? 'selected' : ''}>Minutes</option>
            <option value="hours" ${node.config.unit === 'hours' ? 'selected' : ''}>Hours</option>
            <option value="days" ${node.config.unit === 'days' ? 'selected' : ''}>Days</option>
            <option value="weeks" ${node.config.unit === 'weeks' ? 'selected' : ''}>Weeks</option>
          </select>
        </div>
      </div>
    `
  }

  getConditionPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Condition Configuration</h3>
      <div class="property-group">
        <label>Check If</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="condition_type">
          <option value="">Select what to check...</option>
          <option value="application_status" ${node.config.condition_type === 'application_status' ? 'selected' : ''}>Application status equals</option>
        </select>
      </div>
      ${node.config.condition_type === 'application_status' ? this.getApplicationStatusConditionHTML(node) : ''}
    `
  }

  getApplicationStatusConditionHTML(node) {
    return `
      <div class="property-group">
        <label>Expected Status</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="expected_status">
          <option value="">Select status...</option>
          <option value="created" ${node.config.expected_status === 'created' ? 'selected' : ''}>Created</option>
          <option value="user_details" ${node.config.expected_status === 'user_details' ? 'selected' : ''}>User Details</option>
          <option value="property_details" ${node.config.expected_status === 'property_details' ? 'selected' : ''}>Property Details</option>
          <option value="income_and_loan_options" ${node.config.expected_status === 'income_and_loan_options' ? 'selected' : ''}>Income and Loan Options</option>
          <option value="submitted" ${node.config.expected_status === 'submitted' ? 'selected' : ''}>Submitted</option>
          <option value="processing" ${node.config.expected_status === 'processing' ? 'selected' : ''}>Processing</option>
          <option value="rejected" ${node.config.expected_status === 'rejected' ? 'selected' : ''}>Rejected</option>
          <option value="accepted" ${node.config.expected_status === 'accepted' ? 'selected' : ''}>Accepted</option>
        </select>
      </div>
    `
  }

  getUpdatePropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Update Configuration</h3>
      <div class="property-group">
        <label>Field to Update</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="field">
          <option value="">Select field...</option>
          <option value="application_status" ${node.config.field === 'application_status' ? 'selected' : ''}>Application Status</option>
          <option value="user_notes" ${node.config.field === 'user_notes' ? 'selected' : ''}>User Notes</option>
          <option value="priority" ${node.config.field === 'priority' ? 'selected' : ''}>Priority</option>
        </select>
      </div>
      <div class="property-group">
        <label>New Value</label>
        <input type="text" value="${node.config.value || ''}" 
               data-action="input->workflow-builder#updateNodeConfig" data-property="value">
      </div>
    `
  }

  updateNodeConfig(event) {
    if (!this.selectedNode) return
    
    const property = event.target.dataset.property
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value
    
    this.selectedNode.config[property] = value
    
    // Update node display
    this.refreshNodeDisplay(this.selectedNode)
    
    // Refresh properties panel if trigger type changed
    if (property === 'trigger_type') {
      this.showNodeProperties(this.selectedNode)
    }
    
    this.updateFormData()
  }

  refreshNodeDisplay(node) {
    const nodeElement = document.querySelector(`[data-node-id="${node.id}"]`)
    if (nodeElement) {
      const descElement = nodeElement.querySelector('.node-description')
      if (descElement) descElement.textContent = this.getNodeDescription(node)
    }
  }

  deleteNode(event) {
    const nodeId = parseInt(event.target.dataset.nodeId)
    
    // Remove connections involving this node
    this.connections = this.connections.filter(conn => {
      if (conn.from == nodeId || conn.to == nodeId) {
        const pathElement = this.svgLayer.querySelector(`[data-connection-id="${conn.id}"]`)
        if (pathElement) pathElement.remove()
        return false
      }
      return true
    })
    
    // Remove node
    this.nodes = this.nodes.filter(node => node.id != nodeId)
    
    const nodeElement = document.querySelector(`[data-node-id="${nodeId}"]`)
    if (nodeElement) {
      nodeElement.remove()
    }
    
    // Clear properties if this was the selected node
    if (this.selectedNode && this.selectedNode.id == nodeId) {
      this.selectedNode = null
      this.propertiesTarget.querySelector('.panel-content').innerHTML = 
        '<p class="no-selection">Click on a node to configure its properties</p>'
      this.propertiesTarget.classList.remove('visible')
    }
    
    this.updateFormData()
  }

  handleCanvasClick(event) {
    if (event.target === this.canvasTarget || event.target === this.svgLayer) {
      this.clearSelection()
      if (this.connectingFrom) {
        this.clearConnectionFeedback()
        this.connectingFrom = null
      }
    }
  }

  clearSelection() {
    document.querySelectorAll('.workflow-node').forEach(node => {
      node.classList.remove('selected')
    })
    this.selectedNode = null
    const propertiesContent = this.propertiesTarget.querySelector('.panel-content')
    if (propertiesContent) {
      propertiesContent.innerHTML = '<p class="no-selection">Click on a node to configure its properties</p>'
    }
    this.propertiesTarget.classList.remove('visible')
  }

  // Enhanced quick action methods for building chains
  addQuickEmail() {
    const smartPosition = this.getSmartNodePosition('email')
    const newNode = this.createNode('email', smartPosition.x, smartPosition.y)
    this.selectNode(newNode)
  }

  addQuickDelay() {
    const smartPosition = this.getSmartNodePosition('delay')
    const newNode = this.createNode('delay', smartPosition.x, smartPosition.y)
    this.selectNode(newNode)
  }

  addQuickCondition() {
    const smartPosition = this.getSmartNodePosition('condition')
    const newNode = this.createNode('condition', smartPosition.x, smartPosition.y)
    this.selectNode(newNode)
  }

  getEmailTemplateOptions(selectedTemplateId) {
    if (!this.emailTemplatesValue || this.emailTemplatesValue.length === 0) {
      return '<option value="" disabled>No templates available</option>'
    }
    
    return this.emailTemplatesValue.map(template => {
      const selected = template.id == selectedTemplateId ? 'selected' : ''
      return `<option value="${template.id}" ${selected}>${template.name}</option>`
    }).join('')
  }

  getApplicationStatusChangeHTML(node) {
    const fromStatus = node.config.from_status || ''
    const toStatus = node.config.to_status || ''
    
    return `
      <div class="property-group">
        <label>From Status</label>
        <select data-action="change->workflow-builder#updateApplicationStatusConfig" data-property="from_status">
          <option value="">Select from status...</option>
          ${this.getStatusOptions(fromStatus)}
        </select>
      </div>
      <div class="property-group">
        <label>To Status</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="to_status">
          <option value="">Select to status...</option>
          ${this.getToStatusOptions(fromStatus, toStatus)}
        </select>
      </div>
    `
  }

  getApplicationStatuses() {
    return [
      { key: 'created', value: 0, label: 'Created' },
      { key: 'user_details', value: 1, label: 'User Details' },
      { key: 'property_details', value: 2, label: 'Property Details' },
      { key: 'income_and_loan_options', value: 3, label: 'Income and Loan Options' },
      { key: 'submitted', value: 4, label: 'Submitted' },
      { key: 'processing', value: 5, label: 'Processing' },
      { key: 'rejected', value: 6, label: 'Rejected' },
      { key: 'accepted', value: 7, label: 'Accepted' }
    ]
  }

  getStatusOptions(selectedStatus) {
    return this.getApplicationStatuses()
      .map(status => 
        `<option value="${status.key}" ${status.key === selectedStatus ? 'selected' : ''}>${status.label}</option>`
      ).join('')
  }

  getToStatusOptions(fromStatus, selectedToStatus) {
    if (!fromStatus) return ''
    
    const statuses = this.getApplicationStatuses()
    const fromStatusValue = statuses.find(s => s.key === fromStatus)?.value
    
    if (fromStatusValue === undefined) return ''
    
    return statuses
      .filter(status => status.value > fromStatusValue)
      .map(status => 
        `<option value="${status.key}" ${status.key === selectedToStatus ? 'selected' : ''}>${status.label}</option>`
      ).join('')
  }

  getContractStatuses() {
    return [
      { key: 'awaiting_funding', value: 0, label: 'Awaiting Funding' },
      { key: 'awaiting_investment', value: 1, label: 'Awaiting Investment' },
      { key: 'ok', value: 2, label: 'OK' },
      { key: 'in_holiday', value: 3, label: 'In Holiday' },
      { key: 'in_arrears', value: 4, label: 'In Arrears' },
      { key: 'complete', value: 5, label: 'Complete' }
    ]
  }

  updateApplicationStatusConfig(event) {
    if (!this.selectedNode) return
    
    const property = event.target.dataset.property
    const value = event.target.value
    
    this.selectedNode.config[property] = value
    
    // If from_status changed, reset to_status and update options
    if (property === 'from_status') {
      this.selectedNode.config.to_status = ''
      this.showNodeProperties(this.selectedNode)
    }
    
    this.refreshNodeDisplay(this.selectedNode)
    this.updateFormData()
  }

  loadExistingWorkflow() {
    console.log('Loading existing workflow...')
    
    if (this.workflowDataValue && this.workflowDataValue.trim()) {
      try {
        const workflowData = JSON.parse(this.workflowDataValue)
        
        // Load nodes
        if (workflowData.nodes) {
          workflowData.nodes.forEach(nodeData => {
            this.nodes.push(nodeData)
            this.nextNodeId = Math.max(this.nextNodeId, nodeData.id + 1)
            this.renderNode(nodeData)
          })
        }
        
        // Load connections after nodes are rendered
        if (workflowData.connections) {
          this.connections = workflowData.connections
          // Defer connection drawing slightly to ensure nodes are fully rendered
          setTimeout(() => {
            this.connections.forEach(connection => {
              this.drawConnection(connection)
            })
          }, 50)
        }
        
        console.log('Loaded existing workflow with', this.nodes.length, 'nodes')
      } catch (error) {
        console.error('Failed to load existing workflow:', error)
      }
    }
    
    // Always ensure at least a trigger node exists for new workflows
    if (this.nodes.length === 0) {
      console.log('Creating initial trigger node at', new Date().toISOString())
      this.createNode('trigger', 100, 100)
      console.log('Trigger node created and rendered at', new Date().toISOString())
    }
  }

  updateFormData() {
    const workflowData = {
      nodes: this.nodes,
      connections: this.connections,
      version: '2.0'
    }
    
    // Update trigger type in main form from trigger node
    const triggerNode = this.nodes.find(node => node.type === 'trigger')
    if (triggerNode) {
      const triggerTypeField = document.querySelector('#email_workflow_trigger_type')
      if (triggerTypeField) {
        triggerTypeField.value = triggerNode.config.trigger_type || ''
      }
    }
    
    // Store workflow data in hidden field
    const hiddenField = document.getElementById('workflow_builder_data')
    if (hiddenField) {
      hiddenField.value = JSON.stringify(workflowData)
    }
  }

  hideCanvasHint() {
    const canvasHint = this.canvasTarget.querySelector('.canvas-hint')
    if (canvasHint && this.nodes.length > 0) {
      canvasHint.style.display = 'none'
    }
  }

  // Zoom and Pan functionality
  initZoomAndPan() {
    // Add zoom controls to canvas
    this.canvasTarget.addEventListener('wheel', this.handleZoom.bind(this), { passive: false })
    
    // Add pan functionality with middle mouse button or space+drag
    this.canvasTarget.addEventListener('mousedown', this.handlePanStart.bind(this))
    document.addEventListener('mousemove', this.handlePanMove.bind(this))
    document.addEventListener('mouseup', this.handlePanEnd.bind(this))
    
    // Keyboard shortcuts
    document.addEventListener('keydown', this.handleKeyboard.bind(this))
  }

  handleZoom(event) {
    event.preventDefault()
    
    const rect = this.canvasTarget.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top
    
    const zoomFactor = event.deltaY > 0 ? 0.9 : 1.1
    const newZoom = Math.min(this.maxZoom, Math.max(this.minZoom, this.zoomLevel * zoomFactor))
    
    if (newZoom !== this.zoomLevel) {
      // Zoom towards mouse position
      const zoomRatio = newZoom / this.zoomLevel
      this.panOffset.x = mouseX - (mouseX - this.panOffset.x) * zoomRatio
      this.panOffset.y = mouseY - (mouseY - this.panOffset.y) * zoomRatio
      
      this.zoomLevel = newZoom
      this.applyTransform()
    }
  }

  handlePanStart(event) {
    if (event.button === 1 || (event.button === 0 && event.shiftKey)) { // Middle mouse or shift+left
      this.isPanning = true
      this.panStart = { x: event.clientX, y: event.clientY }
      this.canvasTarget.style.cursor = 'grabbing'
      event.preventDefault()
    }
  }

  handlePanMove(event) {
    if (this.isPanning) {
      const deltaX = event.clientX - this.panStart.x
      const deltaY = event.clientY - this.panStart.y
      
      this.panOffset.x += deltaX
      this.panOffset.y += deltaY
      
      this.panStart = { x: event.clientX, y: event.clientY }
      this.applyTransform()
    }
  }

  handlePanEnd(event) {
    if (this.isPanning) {
      this.isPanning = false
      this.canvasTarget.style.cursor = ''
    }
  }

  handleKeyboard(event) {
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'SELECT' || event.target.tagName === 'TEXTAREA') {
      return // Don't interfere with form inputs
    }

    switch(event.key) {
      case '=':
      case '+':
        event.preventDefault()
        this.zoomIn()
        break
      case '-':
        event.preventDefault()
        this.zoomOut()
        break
      case '0':
        event.preventDefault()
        this.resetZoom()
        break
      case 'f':
        event.preventDefault()
        this.fitToContent()
        break
    }
  }

  applyTransform() {
    const transform = `translate(${this.panOffset.x}px, ${this.panOffset.y}px) scale(${this.zoomLevel})`
    const canvasContent = this.canvasTarget.querySelector('.canvas-content')
    if (canvasContent) {
      canvasContent.style.transform = transform
      canvasContent.style.transformOrigin = '0 0'
    }
    
    // Update grid background to maintain consistent appearance
    const grid = this.canvasTarget.querySelector('.canvas-grid')
    if (grid) {
      const gridSize = this.gridSize * this.zoomLevel
      grid.style.backgroundSize = `${gridSize}px ${gridSize}px`
      grid.style.transform = transform
      grid.style.transformOrigin = '0 0'
    }
    
    // Update zoom level display
    this.updateZoomDisplay()
  }

  zoomIn() {
    const newZoom = Math.min(this.maxZoom, this.zoomLevel * 1.2)
    if (newZoom !== this.zoomLevel) {
      this.zoomLevel = newZoom
      this.applyTransform()
    }
  }

  zoomOut() {
    const newZoom = Math.max(this.minZoom, this.zoomLevel / 1.2)
    if (newZoom !== this.zoomLevel) {
      this.zoomLevel = newZoom
      this.applyTransform()
    }
  }

  resetZoom() {
    this.zoomLevel = 1.0
    this.panOffset = { x: 0, y: 0 }
    this.applyTransform()
  }

  fitToContent() {
    if (this.nodes.length === 0) {
      this.resetZoom()
      return
    }

    // Calculate bounding box of all nodes
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    
    this.nodes.forEach(node => {
      minX = Math.min(minX, node.x)
      minY = Math.min(minY, node.y)
      maxX = Math.max(maxX, node.x + 200) // Node width
      maxY = Math.max(maxY, node.y + 100) // Node height
    })

    const contentWidth = maxX - minX
    const contentHeight = maxY - minY
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    
    const scaleX = (canvasRect.width * 0.8) / contentWidth
    const scaleY = (canvasRect.height * 0.8) / contentHeight
    const scale = Math.min(scaleX, scaleY, this.maxZoom)
    
    this.zoomLevel = Math.max(this.minZoom, scale)
    this.panOffset.x = (canvasRect.width - contentWidth * this.zoomLevel) / 2 - minX * this.zoomLevel
    this.panOffset.y = (canvasRect.height - contentHeight * this.zoomLevel) / 2 - minY * this.zoomLevel
    
    this.applyTransform()
  }

  updateZoomDisplay() {
    const zoomDisplay = document.querySelector('.zoom-level')
    if (zoomDisplay) {
      zoomDisplay.textContent = Math.round(this.zoomLevel * 100) + '%'
    }
  }

  // Panel collapse functionality
  toggleLeftPanel() {
    this.leftPanelCollapsed = !this.leftPanelCollapsed
    const workspace = document.querySelector('.builder-workspace')
    const leftPanel = this.paletteTarget
    const toggleBtn = document.querySelector('.left-panel-toggle')
    const toggleIcon = toggleBtn?.querySelector('.toggle-icon')
    
    if (this.leftPanelCollapsed) {
      workspace.classList.add('left-collapsed')
      leftPanel.classList.add('collapsed')
      if (toggleBtn) {
        toggleBtn.classList.add('collapsed')
        toggleBtn.title = 'Show Components Panel'
      }
      if (toggleIcon) {
        toggleIcon.textContent = '▶'
      }
    } else {
      workspace.classList.remove('left-collapsed')
      leftPanel.classList.remove('collapsed')
      if (toggleBtn) {
        toggleBtn.classList.remove('collapsed')
        toggleBtn.title = 'Hide Components Panel'
      }
      if (toggleIcon) {
        toggleIcon.textContent = '◀'
      }
    }
    
    // Update connection lines after panel animation completes
    // Use requestAnimationFrame and multiple timeouts to ensure proper rendering
    requestAnimationFrame(() => {
      this.updateSVGLayerDimensions()
    })
    
    setTimeout(() => {
      requestAnimationFrame(() => {
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      })
    }, 350) // After CSS animation
    
    setTimeout(() => {
      requestAnimationFrame(() => {
        // Final safety redraw with fresh DOM measurements
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      })
    }, 600) // Extra time for layout settling
  }

  toggleRightPanel() {
    this.rightPanelCollapsed = !this.rightPanelCollapsed
    const workspace = document.querySelector('.builder-workspace')
    const rightPanel = this.propertiesTarget
    const toggleBtn = document.querySelector('.right-panel-toggle')
    const toggleIcon = toggleBtn?.querySelector('.toggle-icon')
    
    if (this.rightPanelCollapsed) {
      workspace.classList.add('right-collapsed')
      rightPanel.classList.add('collapsed')
      if (toggleBtn) {
        toggleBtn.classList.add('collapsed')
        toggleBtn.title = 'Show Properties Panel'
      }
      if (toggleIcon) {
        toggleIcon.textContent = '◀'
      }
    } else {
      workspace.classList.remove('right-collapsed')
      rightPanel.classList.remove('collapsed')
      if (toggleBtn) {
        toggleBtn.classList.remove('collapsed')
        toggleBtn.title = 'Hide Properties Panel'
      }
      if (toggleIcon) {
        toggleIcon.textContent = '▶'
      }
    }
    
    // Update connection lines after panel animation completes
    // Use requestAnimationFrame and multiple timeouts to ensure proper rendering
    requestAnimationFrame(() => {
      this.updateSVGLayerDimensions()
    })
    
    setTimeout(() => {
      requestAnimationFrame(() => {
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      })
    }, 350) // After CSS animation
    
    setTimeout(() => {
      requestAnimationFrame(() => {
        // Final safety redraw with fresh DOM measurements
        this.updateSVGLayerDimensions()
        this.redrawConnections()
      })
    }, 600) // Extra time for layout settling
  }

  updateSVGLayerDimensions() {
    if (this.svgLayer && this.canvasTarget) {
      // Force multiple reflows to ensure layout is fully updated
      this.canvasTarget.offsetHeight
      
      // Wait for any CSS transitions to settle
      const canvasContent = this.canvasTarget.querySelector('.canvas-content')
      if (canvasContent) {
        canvasContent.offsetHeight
      }
      
      // Get updated canvas dimensions after panel resize
      const canvasRect = this.canvasTarget.getBoundingClientRect()
      const contentRect = canvasContent ? canvasContent.getBoundingClientRect() : canvasRect
      
      // Update SVG layer dimensions to match canvas content
      this.svgLayer.style.width = contentRect.width + 'px'
      this.svgLayer.style.height = contentRect.height + 'px'
      
      // Set viewBox to match the content size
      this.svgLayer.setAttribute('viewBox', `0 0 ${contentRect.width} ${contentRect.height}`)
      
      // Ensure SVG is positioned correctly relative to canvas content
      this.svgLayer.style.left = '0px'
      this.svgLayer.style.top = '0px'
      
      // Force another layout recalculation
      this.svgLayer.offsetHeight
      
      console.log('SVG dimensions updated:', contentRect.width, 'x', contentRect.height, 'Canvas:', canvasRect.width, 'x', canvasRect.height)
    }
  }

  // Override coordinate calculations to account for zoom and pan
  getCanvasCoordinates(clientX, clientY) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const x = (clientX - rect.left - this.panOffset.x) / this.zoomLevel
    const y = (clientY - rect.top - this.panOffset.y) / this.zoomLevel
    return { x, y }
  }

  // Update existing mouse handlers to use zoom-aware coordinates

  handleMouseMove(event) {
    if (this.isDraggingNode && this.draggedNodeId) {
      const coords = this.getCanvasCoordinates(event.clientX, event.clientY)
      const x = this.snapToGrid(coords.x - this.dragOffset.x)
      const y = this.snapToGrid(coords.y - this.dragOffset.y)
      
      // Update node position
      const nodeElement = document.querySelector(`[data-node-id="${this.draggedNodeId}"]`)
      if (nodeElement) {
        nodeElement.style.left = `${x}px`
        nodeElement.style.top = `${y}px`
        
        // Update node data
        const node = this.nodes.find(n => n.id == this.draggedNodeId)
        if (node) {
          node.x = x
          node.y = y
          node.gridX = Math.floor(x / this.gridSize)
          node.gridY = Math.floor(y / this.gridSize)
        }
        
        // Redraw connections
        this.redrawConnections()
      }
    }
  }



  disconnect() {
    console.log("Enhanced Workflow Builder disconnected")
    
    // Clean up event listeners and timers
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
    
    if (this.layoutObserver) {
      this.layoutObserver.disconnect()
    }
    
    // Clear any pending timeouts
    clearTimeout(this.resizeTimeout)
    clearTimeout(this.layoutTimeout)
  }
}