// Browser Verification Script for Wholesale Funder UI
// To test: Open admin/lenders/1, open browser dev tools, paste this script and run it

console.log("🏪 WHOLESALE FUNDER UI BROWSER VERIFICATION");
console.log("=" * 60);

// Test 1: Check if Add Wholesale Funder button exists
const addButton = document.querySelector('[data-wholesale-funder-selector-target="toggleButton"]');
if (addButton) {
  console.log("✅ Add Wholesale Funder button found");
  console.log(`   Button text: "${addButton.textContent.trim()}"`);
} else {
  console.log("❌ Add Wholesale Funder button NOT found");
}

// Test 2: Check stimulus controller is connected
const stimulusElement = document.querySelector('[data-controller*="wholesale-funder-selector"]');
if (stimulusElement) {
  console.log("✅ Stimulus controller element found");
  
  // Check if controller is actually connected
  if (stimulusElement.stimulusController) {
    console.log("✅ Stimulus controller is connected");
  } else {
    console.log("⚠️ Stimulus controller element exists but controller not connected");
  }
} else {
  console.log("❌ Stimulus controller element NOT found");
}

// Test 3: Simulate clicking Add Wholesale Funder button
if (addButton) {
  console.log("\n🔄 Testing Add Wholesale Funder button click...");
  
  // Click the button to open selection interface
  addButton.click();
  
  // Wait a moment for interface to load
  setTimeout(() => {
    const selectionInterface = document.querySelector('[data-wholesale-funder-selector-target="selectionInterface"]');
    if (selectionInterface && selectionInterface.style.display !== 'none') {
      console.log("✅ Selection interface opened");
      
      // Check if wholesale funders are loading/loaded
      const container = document.querySelector('[data-wholesale-funder-selector-target="availableFundersContainer"]');
      if (container) {
        console.log(`   Container content: "${container.innerHTML.substring(0, 100)}..."`);
        
        // Look for wholesale funder cards
        const funderCards = container.querySelectorAll('.wholesale-funder-option.clickable-card');
        console.log(`   Found ${funderCards.length} wholesale funder cards`);
        
        if (funderCards.length > 0) {
          console.log("✅ Wholesale funder cards found");
          
          const firstCard = funderCards[0];
          console.log(`   First card funder: "${firstCard.dataset.funderName}"`);
          
          // Test 4: Check card structure
          const hasClickIndicator = firstCard.querySelector('.click-indicator');
          const hasHiddenForm = firstCard.querySelector('form[data-target="hiddenForm"]');
          const hasDataAction = firstCard.hasAttribute('data-action');
          
          console.log(`   ✅ Click indicator: ${hasClickIndicator ? 'Present' : 'Missing'}`);
          console.log(`   ✅ Hidden form: ${hasHiddenForm ? 'Present' : 'Missing'}`);
          console.log(`   ✅ Data action: ${hasDataAction ? 'Present' : 'Missing'}`);
          
          // Test 5: Test hover effect (simulate)
          console.log("\n🎨 Testing hover effects...");
          firstCard.dispatchEvent(new MouseEvent('mouseenter'));
          
          const clickIndicator = firstCard.querySelector('.click-indicator');
          if (clickIndicator) {
            const computedStyle = window.getComputedStyle(clickIndicator);
            console.log(`   Click indicator opacity on hover: ${computedStyle.opacity}`);
          }
          
          // Test 6: Test click interaction (but don't actually submit)
          console.log("\n🖱️ Testing click interaction (simulation only)...");
          
          // Override confirm to prevent actual dialog
          const originalConfirm = window.confirm;
          let confirmCalled = false;
          let confirmMessage = '';
          
          window.confirm = function(message) {
            confirmCalled = true;
            confirmMessage = message;
            console.log(`   Confirm dialog would show: "${message}"`);
            return false; // Don't actually proceed
          };
          
          // Simulate click
          firstCard.click();
          
          // Restore original confirm
          window.confirm = originalConfirm;
          
          if (confirmCalled) {
            console.log("✅ Click triggered confirmation dialog");
            console.log(`   Confirmation message included funder name: ${confirmMessage.includes(firstCard.dataset.funderName)}`);
          } else {
            console.log("❌ Click did NOT trigger confirmation dialog");
          }
          
        } else {
          console.log("⚠️ No wholesale funder cards found - might be loading or none available");
        }
        
      } else {
        console.log("❌ Available funders container NOT found");
      }
      
    } else {
      console.log("❌ Selection interface did NOT open");
    }
    
    console.log("\n🧹 Cleaning up - closing selection interface...");
    const closeButton = document.querySelector('[data-wholesale-funder-selector-target="closeButton"]');
    if (closeButton) {
      closeButton.click();
      console.log("✅ Selection interface closed");
    }
    
    console.log("\n🏁 Browser verification complete!");
    console.log("If all tests show ✅, the UI is working correctly.");
    console.log("If you see ❌ or ⚠️, there are issues to investigate.");
    
  }, 2000); // Wait 2 seconds for AJAX to complete
  
} else {
  console.log("❌ Cannot test button click - button not found");
}

// Test 7: Check CSS classes are loaded
console.log("\n🎨 Checking CSS classes...");
const testElement = document.createElement('div');
testElement.className = 'wholesale-funder-option clickable-card';
document.body.appendChild(testElement);

const computedStyle = window.getComputedStyle(testElement);
console.log(`   cursor property: ${computedStyle.cursor}`);
console.log(`   transition property: ${computedStyle.transition}`);

document.body.removeChild(testElement);

console.log("\n📋 To manually test:");
console.log("1. Click 'Add Wholesale Funder' button");
console.log("2. Hover over a wholesale funder card - should see hover effects");
console.log("3. Click on a card - should see confirmation dialog");
console.log("4. Click OK - should add the wholesale funder and close interface");
console.log("5. Check that the wholesale funder appears in the left column");