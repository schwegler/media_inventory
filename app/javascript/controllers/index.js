import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// Load an island only when its data-controller appears in the current DOM.
lazyLoadControllersFrom("controllers", application)
