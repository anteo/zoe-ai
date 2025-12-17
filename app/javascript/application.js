// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import TC from "@rolemodel/turbo-confirm"
import "./channels"

// Configure turbo-confirm to work with DaisyUI modal
TC.start({
  // Default configuration already works with dialog elements
  // DaisyUI uses dialog element with 'modal' class
  // The default showConfirmCallback uses element.showModal()
  // and hideConfirmCallback uses element.close()
  // which is perfect for DaisyUI dialog elements
  
  // Optional: Customize animation duration if needed
  animationDuration: 200,
  
  // Optional: Add any custom callbacks if needed
  // showConfirmCallback: (element) => {
  //   element.showModal();
  // },
  // hideConfirmCallback: (element) => {
  //   element.close();
  // }
})
