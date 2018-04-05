#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe 'filter work packages', js: true do
  let(:user) { FactoryGirl.create :admin }
  let(:watcher) { FactoryGirl.create :user }
  let(:project) { FactoryGirl.create :project }
  let(:role) { FactoryGirl.create :existing_role, permissions: [:view_work_packages] }
  let(:wp_table) { ::Pages::WorkPackagesTable.new(project) }
  let(:filters) { ::Components::WorkPackages::Filters.new }

  before do
    project.add_member! watcher, role
    login_as(user)
  end

  context 'by watchers' do
    let(:work_package_with_watcher) do
      wp = FactoryGirl.build :work_package, project: project
      wp.add_watcher watcher
      wp.save!

      wp
    end
    let(:work_package_without_watcher) { FactoryGirl.create :work_package, project: project }

    before do
      work_package_with_watcher
      work_package_without_watcher

      wp_table.visit!
    end

    # Regression test for bug #24114 (broken watcher filter)
    it 'should only filter work packages by watcher' do
      filters.open
      loading_indicator_saveguard

      filters.add_filter_by 'Watcher', 'is', watcher.name
      loading_indicator_saveguard

      expect(wp_table).to have_work_packages_listed [work_package_with_watcher]
      expect(wp_table).not_to have_work_packages_listed [work_package_without_watcher]
    end
  end

  context 'by version in project' do
    let(:version) { FactoryGirl.create :version, project: project }
    let(:work_package_with_version) { FactoryGirl.create :work_package, project: project, subject: 'With version', fixed_version: version }
    let(:work_package_without_version) { FactoryGirl.create :work_package, subject: 'Without version', project: project }

    before do
      work_package_with_version
      work_package_without_version

      wp_table.visit!
    end

    it 'allows filtering, saving, retrieving and altering the saved filter' do
      filters.open

      filters.add_filter_by('Version', 'is', version.name)

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_version]
      expect(wp_table).not_to have_work_packages_listed [work_package_without_version]

      wp_table.save_as('Some query name')

      filters.remove_filter 'version'

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_version, work_package_without_version]

      last_query = Query.last

      wp_table.visit_query(last_query)

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_version]
      expect(wp_table).not_to have_work_packages_listed [work_package_without_version]

      filters.open

      filters.expect_filter_by('Version', 'is', version.name)

      filters.set_operator 'Version', 'is not'

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_without_version]
      expect(wp_table).not_to have_work_packages_listed [work_package_with_version]
    end
  end

  context 'by due date outside of a project' do
    let(:work_package_with_due_date) { FactoryGirl.create :work_package, project: project, due_date: Date.today }
    let(:work_package_without_due_date) { FactoryGirl.create :work_package, project: project, due_date: Date.today + 5.days }
    let(:wp_table) { ::Pages::WorkPackagesTable.new }

    before do
      work_package_with_due_date
      work_package_without_due_date

      wp_table.visit!
    end

    it 'allows filtering, saving and retrieving and altering the saved filter' do
      filters.open

      filters.add_filter_by('Due date',
                            'between',
                            [(Date.today - 1.day).strftime('%Y-%m-%d'), Date.today.strftime('%Y-%m-%d')],
                            'dueDate')

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_due_date]
      expect(wp_table).not_to have_work_packages_listed [work_package_without_due_date]

      wp_table.save_as('Some query name')

      filters.remove_filter 'dueDate'

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_due_date, work_package_without_due_date]

      last_query = Query.last

      wp_table.visit_query(last_query)

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_due_date]
      expect(wp_table).not_to have_work_packages_listed [work_package_without_due_date]

      filters.open

      filters.expect_filter_by('Due date',
                               'between',
                               [(Date.today - 1.day).strftime('%Y-%m-%d'), Date.today.strftime('%Y-%m-%d')],
                               'dueDate')

      filters.set_filter 'Due date', 'in more than', '1', 'dueDate'

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_without_due_date]
      expect(wp_table).not_to have_work_packages_listed [work_package_with_due_date]
    end
  end

  context 'by list cf inside a project' do
    let(:type) do
      type = FactoryGirl.create(:type)

      project.types << type

      type
    end

    let(:work_package_with_list_value) do
      wp = FactoryGirl.create :work_package, project: project, type: type
      wp.send("#{list_cf.accessor_name}=", list_cf.custom_options.first.id)
      wp.save!
      wp
    end

    let(:work_package_with_anti_list_value) do
      wp = FactoryGirl.create :work_package, project: project, type: type
      wp.send("#{list_cf.accessor_name}=", list_cf.custom_options.last.id)
      wp.save!
      wp
    end

    let(:list_cf) do
      cf = FactoryGirl.create :list_wp_custom_field

      project.work_package_custom_fields << cf
      type.custom_fields << cf

      cf
    end

    before do
      list_cf
      work_package_with_list_value
      work_package_with_anti_list_value

      wp_table.visit!
    end

    it 'allows filtering, saving and retrieving the saved filter' do
      filters.open

      expect(page).to have_selector('#add_filter_select option', text: list_cf.name, wait: 10)

      filters.add_filter_by(list_cf.name,
                            'is not',
                            list_cf.custom_options.last.value,
                            "customField#{list_cf.id}")

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_list_value]
      expect(wp_table).not_to have_work_packages_listed [work_package_with_anti_list_value]

      wp_table.save_as('Some query name')

      filters.remove_filter "customField#{list_cf.id}"

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_list_value, work_package_with_anti_list_value]

      last_query = Query.last

      wp_table.visit_query(last_query)

      loading_indicator_saveguard
      expect(wp_table).to have_work_packages_listed [work_package_with_list_value]
      expect(wp_table).not_to have_work_packages_listed [work_package_with_anti_list_value]

      filters.open

      filters.expect_filter_by(list_cf.name,
                               'is not',
                               list_cf.custom_options.last.value,
                               "customField#{list_cf.id}")
    end
  end

  context 'by attachment content' do
    let(:attachment_a) { FactoryGirl.create(:attachment, filename: 'attachment-first.pdf') }
    let(:attachment_b) { FactoryGirl.create(:attachment, filename: 'attachment-second.pdf') }
    let(:wp_with_attachment_a) { FactoryGirl.create :work_package, subject: 'WP attachment A', project: project, attachments: [attachment_a] }
    let(:wp_with_attachment_b) { FactoryGirl.create :work_package, subject: 'WP attachment B', project: project, attachments: [attachment_b] }
    let(:wp_without_attachment) { FactoryGirl.create :work_package, subject: 'WP no attachment', project: project}
    let(:wp_table) { ::Pages::WorkPackagesTable.new }

    before do
      allow(EnterpriseToken).to receive(:allows_to?).and_return(false)
      allow(EnterpriseToken).to receive(:allows_to?).with(:attachment_filters).and_return(true)

      allow_any_instance_of(Plaintext::Resolver).to receive(:text).and_return('I am the first text $1.99.')
      wp_with_attachment_a
      ExtractFulltextJob.new(attachment_a.id).perform
      allow_any_instance_of(Plaintext::Resolver).to receive(:text).and_return('I am the second text.')
      wp_with_attachment_b
      ExtractFulltextJob.new(attachment_b.id).perform
      wp_without_attachment

      wp_table.visit!
    end

    if OpenProject::Database::allows_tsv?
      it 'allows filtering and retrieving and altering the saved filter' do
        filters.open

        # content contains with multiple hits
        filters.add_filter_by('Attachment content',
                              'contains',
                              ['text'],
                              'attachmentContent')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_a, wp_with_attachment_b]
        expect(wp_table).not_to have_work_packages_listed [wp_without_attachment]

        # content contains single hit with numbers
        filters.remove_filter 'attachmentContent'

        filters.add_filter_by('Attachment content',
                              'contains',
                              ['first 1.99'],
                              'attachmentContent')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_a]
        expect(wp_table).not_to have_work_packages_listed [wp_without_attachment, wp_with_attachment_b]

        filters.remove_filter 'attachmentContent'

        # content does not contain
        filters.add_filter_by('Attachment content',
                              'doesn\'t contain',
                              ['first'],
                              'attachmentContent')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_b]
        expect(wp_table).not_to have_work_packages_listed [wp_without_attachment, wp_with_attachment_a]

        filters.remove_filter 'attachmentContent'

        # ignores special characters
        filters.add_filter_by('Attachment content',
                              'contains',
                              ['! first:* \')'],
                              'attachmentContent')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_a]
        expect(wp_table).not_to have_work_packages_listed [wp_without_attachment, wp_with_attachment_b]

        filters.remove_filter 'attachmentContent'

        # file name contains
        filters.add_filter_by('Attachment file name',
                              'contains',
                              ['first'],
                              'attachmentFileName')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_a]
        expect(wp_table).not_to have_work_packages_listed [wp_without_attachment, wp_with_attachment_b]

        filters.remove_filter 'attachmentFileName'

        # file name does not contain
        filters.add_filter_by('Attachment file name',
                              'doesn\'t contain',
                              ['first'],
                              'attachmentFileName')

        loading_indicator_saveguard
        expect(wp_table).to have_work_packages_listed [wp_with_attachment_b]
        expect(wp_table).not_to have_work_packages_listed [wp_with_attachment_a]
      end
    end

  end

  context 'DB does not offer TSVector support' do
    before do
      allow(OpenProject::Database).to receive(:allows_tsv?).and_return(false)
    end

    it "does not offer attachment filters" do
      expect(page).to_not have_select 'add_filter_select', with_options: ['Attachment content', 'Attachment file name']
    end
  end
end
