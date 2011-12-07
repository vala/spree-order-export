module OrderExport
  module ReportsControllerExt
    def self.included(base)
      base.class_eval do

        def order_export
          export = !params[:search].nil?
#          params[:search] = {} unless params[:search]

#          if params[:search][:created_at_greater_than].blank?
#            params[:search][:created_at_greater_than] = Time.zone.now.beginning_of_month
#          else
#            params[:search][:created_at_greater_than] = Time.zone.parse(params[:search][:created_at_greater_than]).beginning_of_day rescue Time.zone.now.beginning_of_month
#          end

#          if params[:search] && !params[:search][:created_at_less_than].blank?
#            params[:search][:created_at_less_than] = Time.zone.parse(params[:search][:created_at_less_than]).end_of_day rescue ""
#          end

          #params[:search][:completed_at_not_null] ||= "1"
          #if params[:search].delete(:completed_at_not_null) == "1"
          #  params[:search][:completed_at_not_null] = true
          #end

          #params[:search][:order] ||= "descend_by_created_at"

         params[:search] ||= {}
         params[:search][:completed_at_is_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
         @show_only_completed = params[:search][:completed_at_is_not_null].present?
         params[:search][:meta_sort] ||= @show_only_completed ? 'completed_at.desc' : 'created_at.desc'

         @search = Order.metasearch(params[:search])

         if !params[:search][:created_at_greater_than].blank?
           params[:search][:created_at_greater_than] = Time.zone.parse(params[:search][:created_at_greater_than]).beginning_of_day rescue ""
         end

         if !params[:search][:created_at_less_than].blank?
           params[:search][:created_at_less_than] = Time.zone.parse(params[:search][:created_at_less_than]).end_of_day rescue ""
         end

         if @show_only_completed
           params[:search][:completed_at_greater_than] = params[:search].delete(:created_at_greater_than)
           params[:search][:completed_at_less_than] = params[:search].delete(:created_at_less_than)
         end

         @orders = Order.metasearch(params[:search]).includes([:user, :shipments, :payments]).page(params[:page]).per(Spree::Config[:orders_per_page])

#         @search = Order.search(params[:search])

          render and return unless export

#        @orders = @search.all


          orders_export = CSV.generate(:col_sep => ";", :row_sep => "\r\n") do |csv|
            headers = [
              t('order_export_ext.header.last_updated'),
              t('order_export_ext.header.completed_at'),
              t('order_export_ext.header.number'),
              t('order_export_ext.header.name'),
              t('order_export_ext.header.address'),
              t('order_export_ext.header.phone'),
              t('order_export_ext.header.email'),
              t('order_export_ext.header.variant_name'),
              t('order_export_ext.header.quantity'),
              t('order_export_ext.header.order_total'),
              t('order_export_ext.header.payment_method')
            ]

            csv << headers

            @orders.each do |order|
              order.line_items.each do |line_item|
                csv_line = []
                csv_line << order.updated_at
                csv_line << order.completed_at
                csv_line << order.number

                if order.bill_address
                  csv_line << order.bill_address.full_name
                  address_line = ""
                  address_line << order.bill_address.address1 + " " if order.bill_address.address1?
                  address_line << order.bill_address.address2 + " " if order.bill_address.address2?
                  address_line << order.bill_address.city + " " if order.bill_address.city?
                  address_line << order.bill_address.country.name + " " if order.bill_address.country_id?
                  csv_line << address_line
                  csv_line << order.bill_address.phone if order.bill_address.phone?
                else
                  csv_line << ""
                  csv_line << ""
                end
                csv_line << order.email || ""
                csv_line << line_item.variant.name
                csv_line << line_item.quantity
                csv_line << order.total.to_s
                csv_line << order.payment_method.name
                csv << csv_line
              end
            end
          end
          send_data orders_export, :type => 'text/csv', :filename => "Orders-#{Time.now.strftime('%Y%m%d')}.csv"
        end
      end
    end
  end
end

