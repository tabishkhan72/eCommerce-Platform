// === Rails Core Initialization ===
import "@rails/actioncable"
import "@rails/actiontext"
import "@hotwired/turbo-rails"
import \* as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

// === Third-Party Library Initialization ===
import "trix"
import "chartkick"
import "Chart.bundle"
import LocalTime from "local-time"
import "mapkick/bundle"
LocalTime.start()

// === Admin Helper Scripts ===
import 'spree/admin/helpers/tinymce'
import 'spree/admin/helpers/canvas'
import 'spree/admin/helpers/trix/video\_embed'
import 'spree/admin/helpers/bootstrap'

// === Stimulus Initialization ===
import { Application } from "@hotwired/stimulus"
let application = window\.Stimulus || Application.start()
application.debug = false
window\.Stimulus = application

// === Core Stimulus Controllers ===
import AutoSubmit from '@stimulus-components/auto-submit'
import CheckboxSelectAll from 'stimulus-checkbox-select-all'
import TextareaAutogrow from 'stimulus-textarea-autogrow'
import Notification from 'stimulus-notification'
import PasswordVisibility from 'stimulus-password-visibility'
import RailsNestedForm from '@stimulus-components/rails-nested-form'
import Reveal from 'stimulus-reveal-controller'
import Sortable from 'stimulus-sortable'
import { Tabs } from 'tailwindcss-stimulus-components'

// === Spree-Specific Stimulus Controllers ===
import ActiveStorageUpload from 'spree/admin/controllers/active\_storage\_upload\_controller'
import AssetUploaderController from 'spree/admin/controllers/asset\_uploader\_controller'
import AutocompleteSelectController from 'spree/admin/controllers/autocomplete\_select\_controller'
import BetterSliderController from 'spree/admin/controllers/better\_slider\_controller'
import BlockFormController from 'spree/admin/controllers/block\_form\_controller'
import BootstrapTabs from 'spree/admin/controllers/bootstrap\_tabs\_controller'
import BulkOperationController from 'spree/admin/controllers/bulk\_operation\_controller'
import CalculatorFieldsController from 'spree/admin/controllers/calculator\_fields\_controller'
import CalendarRangeController from 'spree/admin/controllers/calendar\_range\_controller'
import Clipboard from 'spree/admin/controllers/clipboard\_controller'
import ColorPaletteController from 'spree/admin/controllers/color\_palette\_controller'
import ColorPickerController from 'spree/admin/controllers/color\_picker\_controller'
import FiltersController from 'spree/admin/controllers/filters\_controller'
import FontPickerController from 'spree/admin/controllers/font\_picker\_controller'
import MediaFormController from 'spree/admin/controllers/media\_form\_controller'
import MultiInputController from 'spree/admin/controllers/multi\_input\_controller'
import OrderBillingAddressController from 'spree/admin/controllers/order\_billing\_address\_controller'
import PageBuilderController from 'spree/admin/controllers/page\_builder\_controller'
import PasswordToggle from 'spree/admin/controllers/password\_toggle\_controller'
import ProductFormController from 'spree/admin/controllers/product\_form\_controller'
import RangeInputController from 'spree/admin/controllers/range\_input\_controller'
import ReturnItemsController from 'spree/admin/controllers/return\_items\_controller'
import ReplaceController from 'spree/admin/controllers/replace\_controller'
import RowLinkController from 'spree/admin/controllers/row\_link\_controller'
import RuleFormController from 'spree/admin/controllers/rule\_form\_controller'
import SearchPickerController from 'spree/admin/controllers/search\_picker\_controller'
import SectionFormController from 'spree/admin/controllers/section\_form\_controller'
import SelectController from 'spree/admin/controllers/select\_controller'
import SeoFormController from 'spree/admin/controllers/seo\_form\_controller'
import SlugFormController from 'spree/admin/controllers/slug\_form\_controller'
import SortableTree from 'spree/admin/controllers/sortable\_tree\_controller'
import StockTransferController from 'spree/admin/controllers/stock\_transfer\_controller'
import StoreFormController from 'spree/admin/controllers/store\_form\_controller'
import UnitSystemController from 'spree/admin/controllers/unit\_system\_controller'
import VariantsFormController from 'spree/admin/controllers/variants\_form\_controller'
import WebhooksSubscriberEventsController from 'spree/admin/controllers/webhook\_subscriber\_events\_controller'
import AddressAutocompleteController from 'spree/core/controllers/address\_autocomplete\_controller'
import AddressFormController from 'spree/core/controllers/address\_form\_controller'
import EnableButtonController from 'spree/core/controllers/enable\_button\_controller'

// === Stimulus Controller Registration ===
application.register('active-storage-upload', ActiveStorageUpload)
application.register('address-autocomplete', AddressAutocompleteController)
application.register('address-form', AddressFormController)
application.register('asset-uploader', AssetUploaderController)
application.register('auto-submit', AutoSubmit)
application.register('autocomplete-select', AutocompleteSelectController)
application.register('better-slider', BetterSliderController)
application.register('block-form', BlockFormController)
application.register('bootstrap-tabs', BootstrapTabs)
application.register('bulk-operation', BulkOperationController)
application.register('calculator-fields', CalculatorFieldsController)
application.register('calendar-range', CalendarRangeController)
application.register('checkbox-select-all', CheckboxSelectAll)
application.register('clipboard', Clipboard)
application.register('color-palette', ColorPaletteController)
application.register('color-picker', ColorPickerController)
application.register('enable-button', EnableButtonController)
application.register('filters', FiltersController)
application.register('font-picker', FontPickerController)
application.register('media-form', MediaFormController)
application.register('multi-input', MultiInputController)
application.register('nested-form', RailsNestedForm)
application.register('notification', Notification)
application.register('order-billing-address', OrderBillingAddressController)
application.register('page-builder', PageBuilderController)
application.register('password-toggle', PasswordToggle)
application.register('password-visibility', PasswordVisibility)
application.register('product-form', ProductFormController)
application.register('range-input', RangeInputController)
application.register('replace', ReplaceController)
application.register('return-items', ReturnItemsController)
application.register('reveal', Reveal)
application.register('row-link', RowLinkController)
application.register('rule-form', RuleFormController)
application.register('search-picker', SearchPickerController)
application.register('section-form', SectionFormController)
application.register('select', SelectController)
application.register('seo-form', SeoFormController)
application.register('slug-form', SlugFormController)
application.register('sortable', Sortable)
application.register('sortable-tree', SortableTree)
application.register('stock-transfer', StockTransferController)
application.register('store-form', StoreFormController)
application.register('tabs', Tabs)
application.register('textarea-autogrow', TextareaAutogrow)
application.register('unit-system', UnitSystemController)
application.register('variants-form', VariantsFormController)
application.register('webhooks-subscriber-events', WebhooksSubscriberEventsController)

// === Trix Configuration ===
Trix.config.blockAttributes.heading1.tagName = 'h2'

// === Turbo Navigation UI Effects ===
document.addEventListener('turbo\:before-visit', () => {
const content = document.getElementById('content')
if (content) content.classList.add('blurred')
})

document.addEventListener('turbo\:load', () => {
const content = document.getElementById('content')
if (content) content.classList.remove('blurred')
})

// === Turbo Form Submission Progress Bar ===
document.addEventListener('turbo\:submit-start', () => {
Turbo.navigator.delegate.adapter.progressBar.setValue(0)
Turbo.navigator.delegate.adapter.progressBar.show()
})

document.addEventListener('turbo\:submit-end', () => {
Turbo.navigator.delegate.adapter.progressBar.setValue(1)
Turbo.navigator.delegate.adapter.progressBar.hide()
})
