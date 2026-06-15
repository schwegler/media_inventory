import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

import ModalController from "controllers/modal_controller"
application.register("modal", ModalController)

import SeasonTabsController from "controllers/season_tabs_controller"
application.register("season-tabs", SeasonTabsController)
