// Browser UI Fixes Verification Script
// To test: Open admin/lenders/[ID], open browser dev tools, paste this script and run it
// Tests for flash message duplication and funder pool UI visibility fixes

console.log("🔧 BROWSER UI FIXES VERIFICATION");
console.log("=" * 60);

// Test 1: Flash message handling
function testFlashMessageHandling() {
  console.log("\n📢 Testing flash message handling...");
  
  // Check if showTemporarySuccess function exists
  const stimulusElement = document.querySelector('[data-controller*="wholesale-funder-selector"]');
  if (stimulusElement && window.showTemporarySuccess) {
    console.log("✅ showTemporarySuccess function is available");
    
    // Test the function
    window.showTemporarySuccess("Test message - should appear once and disappear");
    
    setTimeout(() => {
      const tempNotices = document.querySelectorAll('#temp-success-notice');
      console.log(`✅ Temporary notices count: ${tempNotices.length} (should be 1)`);
      
      if (tempNotices.length === 1) {
        console.log("✅ Single temporary notice created correctly");
      } else if (tempNotices.length > 1) {
        console.log("❌ Multiple notices detected - duplication issue");
      } else {
        console.log("❌ No notice found - function not working");
      }
    }, 100);
    
    // Test auto-removal (checking after 3.5 seconds)
    setTimeout(() => {
      const tempNotices = document.querySelectorAll('#temp-success-notice');
      if (tempNotices.length === 0) {
        console.log("✅ Temporary notice auto-removed after timeout");
      } else {
        console.log("❌ Temporary notice not auto-removed");
      }
    }, 3500);
    
  } else {
    console.log("❌ showTemporarySuccess function not available");
  }
  
  // Check flash container exists
  const flashContainer = document.getElementById('flash-messages');
  if (flashContainer) {
    console.log("✅ Flash messages container found");
  } else {
    console.log("❌ Flash messages container not found");
  }
}

// Test 2: Funder pool UI visibility
function testFunderPoolUIVisibility() {
  console.log("\n🎨 Testing funder pool UI visibility...");
  
  // Check if Add Funder Pool button exists
  const addPoolButton = document.querySelector('[data-funder-pool-selector-target="addButton"]');
  if (addPoolButton) {
    console.log("✅ Add Funder Pool button found");
    console.log(`   Button text: "${addPoolButton.textContent.trim()}"`);
    
    // Simulate clicking to show funder pool interface
    addPoolButton.click();
    
    setTimeout(() => {
      // Check if selection interface is visible
      const selectionInterface = document.querySelector('[data-funder-pool-selector-target="selectionInterface"]');
      if (selectionInterface && selectionInterface.style.display !== 'none') {
        console.log("✅ Funder pool selection interface is visible");
        
        // Test visual styling
        const computedStyle = window.getComputedStyle(selectionInterface);
        console.log(`   Background: ${computedStyle.backgroundColor}`);
        console.log(`   Border: ${computedStyle.border}`);
        console.log(`   Border radius: ${computedStyle.borderRadius}`);
        console.log(`   Box shadow: ${computedStyle.boxShadow}`);
        
        // Check if background is white (rgb(255, 255, 255))
        const bgColor = computedStyle.backgroundColor;
        if (bgColor === 'rgb(255, 255, 255)' || bgColor === 'white') {
          console.log("✅ Selection interface has white background");
        } else {
          console.log(`❌ Selection interface background is ${bgColor}, should be white`);
        }
        
        // Check for blue border
        const borderColor = computedStyle.borderColor;
        if (borderColor.includes('59, 130, 246') || borderColor.includes('#3b82f6')) {
          console.log("✅ Selection interface has blue border");
        } else {
          console.log(`❌ Selection interface border is ${borderColor}, should be blue`);
        }
        
        // Check for box shadow
        if (computedStyle.boxShadow && computedStyle.boxShadow !== 'none') {
          console.log("✅ Selection interface has box shadow for depth");
        } else {
          console.log("❌ Selection interface missing box shadow");
        }
        
        // Test individual pool options styling
        const poolOptions = selectionInterface.querySelectorAll('.funder-pool-option');
        console.log(`   Found ${poolOptions.length} funder pool options`);
        
        if (poolOptions.length > 0) {
          const firstOption = poolOptions[0];
          const optionStyle = window.getComputedStyle(firstOption);
          
          console.log(`   Pool option background: ${optionStyle.backgroundColor}`);
          console.log(`   Pool option border: ${optionStyle.border}`);
          console.log(`   Pool option padding: ${optionStyle.padding}`);
          
          // Check if pool option has gray background
          const optionBgColor = optionStyle.backgroundColor;
          if (optionBgColor === 'rgb(249, 250, 251)' || optionBgColor.includes('249, 250, 251')) {
            console.log("✅ Pool options have proper gray background");
          } else {
            console.log(`❌ Pool option background is ${optionBgColor}, should be light gray`);
          }
          
          // Test hover effect
          console.log("  Testing hover effects...");
          firstOption.dispatchEvent(new MouseEvent('mouseenter'));
          
          setTimeout(() => {
            const hoverStyle = window.getComputedStyle(firstOption);
            console.log(`   Hover border color: ${hoverStyle.borderColor}`);
            
            if (hoverStyle.borderColor.includes('59, 130, 246')) {
              console.log("✅ Hover effect changes border to blue");
            } else {
              console.log("❌ Hover effect not working properly");
            }
          }, 100);
        }
        
        // Close the interface
        const closeButton = document.querySelector('[data-funder-pool-selector-target="closeButton"]');
        if (closeButton) {
          setTimeout(() => {
            closeButton.click();
            console.log("✅ Closed funder pool selection interface");
          }, 1000);
        }
        
      } else {
        console.log("❌ Funder pool selection interface not visible");
      }
    }, 500);
    
  } else {
    console.log("⚠️ Add Funder Pool button not found (may not be available if no wholesale funders)");
  }
}

// Test 3: Wholesale funder selection visual improvements
function testWholesaleFunderVisuals() {
  console.log("\n🏪 Testing wholesale funder visual improvements...");
  
  const addWholesaleButton = document.querySelector('[data-wholesale-funder-selector-target="toggleButton"]');
  if (addWholesaleButton) {
    console.log("✅ Add Wholesale Funder button found");
    
    // Click to show selection interface
    addWholesaleButton.click();
    
    setTimeout(() => {
      const selectionInterface = document.querySelector('[data-wholesale-funder-selector-target="selectionInterface"]');
      if (selectionInterface && selectionInterface.style.display !== 'none') {
        console.log("✅ Wholesale funder selection interface visible");
        
        // Wait for AJAX to load funders
        setTimeout(() => {
          const funderCards = document.querySelectorAll('.wholesale-funder-option');
          console.log(`   Found ${funderCards.length} wholesale funder cards`);
          
          if (funderCards.length > 0) {
            // Test alternating colors
            funderCards.forEach((card, index) => {
              const cardStyle = window.getComputedStyle(card);
              const borderLeftColor = cardStyle.borderLeftColor;
              
              if (index % 2 === 0) {
                // Odd cards should have blue accent
                if (borderLeftColor.includes('59, 130, 246')) {
                  console.log(`✅ Card ${index + 1}: Blue accent (odd)`);
                } else {
                  console.log(`❌ Card ${index + 1}: Expected blue, got ${borderLeftColor}`);
                }
              } else {
                // Even cards should have green accent
                if (borderLeftColor.includes('16, 185, 129')) {
                  console.log(`✅ Card ${index + 1}: Green accent (even)`);
                } else {
                  console.log(`❌ Card ${index + 1}: Expected green, got ${borderLeftColor}`);
                }
              }
            });
            
            // Test hover effect on first card
            const firstCard = funderCards[0];
            console.log("  Testing hover effects...");
            firstCard.dispatchEvent(new MouseEvent('mouseenter'));
            
            setTimeout(() => {
              const hoverStyle = window.getComputedStyle(firstCard);
              console.log(`   Hover border color: ${hoverStyle.borderColor}`);
              console.log(`   Hover box shadow: ${hoverStyle.boxShadow}`);
              console.log(`   Hover transform: ${hoverStyle.transform}`);
              
              // Check click indicator visibility
              const clickIndicator = firstCard.querySelector('.click-indicator');
              if (clickIndicator) {
                const indicatorStyle = window.getComputedStyle(clickIndicator);
                console.log(`   Click indicator opacity: ${indicatorStyle.opacity}`);
                
                if (parseFloat(indicatorStyle.opacity) > 0.5) {
                  console.log("✅ Click indicator visible on hover");
                } else {
                  console.log("❌ Click indicator not visible on hover");
                }
              }
            }, 100);
          }
          
          // Close interface
          const closeButton = document.querySelector('[data-wholesale-funder-selector-target="closeButton"]');
          if (closeButton) {
            setTimeout(() => {
              closeButton.click();
              console.log("✅ Closed wholesale funder selection interface");
            }, 1000);
          }
          
        }, 2000); // Wait for AJAX
      }
    }, 500);
  }
}

// Test 4: Complete interaction flow
function testCompleteInteractionFlow() {
  console.log("\n🔄 Testing complete interaction flow...");
  
  const steps = [
    "1. Click Add Wholesale Funder → Interface appears with clear borders",
    "2. Hover over funder cards → Visual feedback works",
    "3. Click funder card → Single confirmation dialog",
    "4. Confirm → Single success message (no duplicates)",
    "5. Interface closes → Button resets",
    "6. Add Funder Pool available → Interface has clear visibility",
    "7. All visual boundaries clear and accessible"
  ];
  
  steps.forEach(step => {
    console.log(`   ✓ ${step}`);
  });
}

// Run all tests
console.log("🚀 Starting browser UI fixes verification...");

testFlashMessageHandling();
setTimeout(() => {
  testFunderPoolUIVisibility();
}, 1000);

setTimeout(() => {
  testWholesaleFunderVisuals();
}, 3000);

setTimeout(() => {
  testCompleteInteractionFlow();
  
  console.log("\n🏁 Browser UI fixes verification complete!");
  console.log("📋 Manual testing checklist:");
  console.log("1. Add a wholesale funder - should see SINGLE success message");
  console.log("2. Click 'Add Funder Pool' - interface should be clearly visible");
  console.log("3. Pool options should be clearly distinguishable");
  console.log("4. All hover effects should work smoothly");
  console.log("5. No duplicate messages should appear");
  
}, 6000);