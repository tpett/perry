Factory.define(:widget, :default_strategy => :attributes_for, :class => "Perry::Test::Wearhouse::Widget") do |f|
  f.sequence(:string) { |n| "widget_#{n}"}
  f.integer 1
  f.float 1.0
  f.text "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
end

Factory.define(:subwidget, :default_strategy => :attributes_for, :class => "Perry::Test::Wearhouse::Subwidget") do |f|
  f.sequence(:string) { |n| "subwidget_#{n}"}
end

Factory.define(:schematic, :default_strategy => :attributes_for, :class => "Perry::Test::Wearhouse::Schematic") do |f|
  f.sequence(:string) { |n| "schematic_#{n}"}
end
