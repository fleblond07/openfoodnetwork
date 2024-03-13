import { Controller } from "stimulus";

// Allows a form section to "pop out" and show additional options
export default class PopoutController extends Controller {
  static targets = ["button", "dialog"];

  connect() {
    this.first_input = this.dialogTarget.querySelector("input");
    this.displayElements = Array.from(this.element.querySelectorAll('input:not([type="hidden"]'));

    // Show when click or down-arrow on button
    this.buttonTarget.addEventListener("click", this.show.bind(this));
    this.buttonTarget.addEventListener("keydown", this.applyKeyAction.bind(this));

    // Close when click or tab outside of dialog. Run async (don't block primary event handlers).
    this.closeIfOutsideBound = this.closeIfOutside.bind(this); // Store reference for removing listeners later.
    document.addEventListener("click", this.closeIfOutsideBound, { passive: true });
    document.addEventListener("focusin", this.closeIfOutsideBound, { passive: true });
  }

  disconnect() {
    // Clean up handlers registered outside the controller element.
    // (jest cleans up document too early)
    if (document) {
      document.removeEventListener("click", this.closeIfOutsideBound);
      document.removeEventListener("focusin", this.closeIfOutsideBound);
    }
  }

  show(e) {
    this.dialogTarget.style.display = "block";
    this.first_input.focus();
    e.preventDefault();
  }

  // Apply an appropriate action, behaving similar to a dropdown
  // Shows the popout and applies the value where appropriate
  applyKeyAction(e) {
    if ([38, 40].includes(e.keyCode)) {
      // Show if Up or Down arrow
      this.show(e);
    } else if (e.key.match(/^[\d\w]$/)) {
      // Show, and apply value if it's a digit or word character
      this.show(e);
      this.first_input.value = e.key;
    }
  }

  close() {
    // Close if not already closed
    if (this.dialogTarget.style.display != "none") {
      // Check every element for browser-side validation, before the fields get hidden.
      if (!this.#enabledDisplayElements().every((element) => element.reportValidity())) {
        // If any fail, don't close
        return;
      }

      // Update button to represent any changes
      this.buttonTarget.innerText = this.#displayValue();
      this.buttonTarget.classList.toggle("changed", this.#isChanged());

      this.dialogTarget.style.display = "none";
    }
  }

  closeIfOutside(e) {
    if (!this.dialogTarget.contains(e.target)) {
      this.close();
    }
  }

  // Close if checked
  closeIfChecked(e) {
    if (e.target.checked) {
      this.close();
      this.buttonTarget.focus();
    }
  }

  // private

  // Summarise the active field(s)
  #displayValue() {
    let values = this.#enabledDisplayElements().map((element) => {
      if (element.type == "checkbox") {
        if (element.checked && element.labels[0]) {
          return element.labels[0].innerText;
        }
      } else {
        return element.value;
      }
    });
    // Filter empty values and convert to string
    return values.filter(Boolean).join();
  }

  #isChanged() {
    return this.#enabledDisplayElements().some((element) => element.classList.contains("changed"));
  }

  #enabledDisplayElements() {
    return this.displayElements.filter((element) => !element.disabled);
  }
}
