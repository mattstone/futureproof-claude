# Manual Testing Instructions for Property Autocomplete

## 🧪 Browser Test Protocol

### Step 1: Create Test User
1. Open browser and go to: http://localhost:3000/users/sign_up
2. Fill out the form:
   - First Name: Test
   - Last Name: User
   - Email: test123@example.com
   - Country: Australia
   - Password: password123
   - Confirm Password: password123
   - Check "I accept the Terms and Conditions"
   - Complete reCAPTCHA
3. Click "Create Account"
4. Should redirect to applications page

### Step 2: Test Property Autocomplete
1. Should now be on: http://localhost:3000/applications/new
2. Verify page loads without error
3. Look for "Property Address" field
4. Type 3+ characters into the address field (e.g., "123 Test Street")
5. Verify suggestions dropdown appears
6. Check for loading indicator
7. Select a property suggestion

### Step 3: Verify Property Preview
1. After selecting a property, check if:
   - Property preview section becomes visible
   - Property images appear in gallery
   - Property details show (bedrooms, bathrooms, etc.)
   - Home value slider updates automatically
   - CoreLogic valuation range displays

### Step 4: Verify JavaScript Functionality
1. Open browser DevTools (F12)
2. Go to Console tab
3. Type property address and watch for console logs:
   - "🔍 Searching for: [query]"
   - "✅ Found X suggestions for [query]"
   - "🏠 Fetching property details for: [id]"
   - "✅ Property details received: [data]"

### Step 5: Verify CSS Styling
1. Check that property preview looks styled and professional
2. Verify image gallery has thumbnails and main image
3. Check property details grid layout
4. Verify hover effects on images and buttons

### Expected Results:
- ✅ User signup works
- ✅ Applications page loads without 500 error
- ✅ Property autocomplete field accepts input
- ✅ Suggestions appear after 3+ characters
- ✅ Property preview shows after selection
- ✅ Home value updates automatically
- ✅ Styling looks professional and modern

### Common Issues to Check:
- ❌ 500 Server Error → Check Rails logs
- ❌ Missing property preview → Check JavaScript console
- ❌ Ugly styling → Check CSS compilation
- ❌ No suggestions → Check autocomplete endpoint
- ❌ JavaScript errors → Check browser console

### Files to Check if Issues:
- Application model: `app/models/application.rb`
- Applications controller: `app/controllers/applications_controller.rb`
- View template: `app/views/applications/new.html.erb`
- JavaScript: `app/javascript/controllers/property_autocomplete_controller.js`
- CSS: `app/assets/stylesheets/application_form.css`