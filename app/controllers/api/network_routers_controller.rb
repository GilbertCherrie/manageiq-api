module Api
  class NetworkRoutersController < BaseController
    include Subcollections::Tags

    def create_resource(type, _id = nil, data = {})
      assert_id_not_specified(data, type)
      create_action_result_handler(type, data['ems_id'], :task_id => true, :name => data['name']) do |ems|
        # returning the task_id
        ems.create_network_router_queue(User.current_userid, parse_data(data, type))
      end
    end

    def edit_resource(type, id, data)
      action_result_handler(type, id, :update, :task_id => true) do |network_router|
        # returning the task_id
        network_router.update_network_router_queue(User.current_userid, parse_data(data, type))
      end
    end

    def delete_resource(type, id, _data = {})
      action_result_handler(type, id, :delete, :task_id => true) do |network_router|
        # returning the task_id
        network_router.delete_network_router_queue(User.current_userid)
      end
    end

    def options
      if params.key?("id")
        options_by_id
      elsif params.key?("ems_id")
        options_by_ems_id
      else
        super
      end
    end

    private

    # convert an api request with our own ruby ids to
     # something that we can send over the queue and on to the provider/ems
    def parse_data(params, type = :network_router)
      # think only name admin_state_up and enable_snat are the params we need
      options = %w[name admin_state_up ems_id cloud_group_id cloud_subnet_id
                   cloud_network_id].each_with_object({}) do |param, opt|
        opt[param.to_sym] = params[param] if params[param]
      end

      if (cloud_tenant_id = params["cloud_tenant_id"])
        # we need to get away from this.
        options[:cloud_tenant] = resource_search(cloud_tenant_id, type, collection_class(:cloud_tenants))
      end
      gateway_options = options[:external_gateway_info] = {}

      if (cloud_network_id = params["cloud_network_id"]).present?
        network = resource_search(cloud_network_id, type, collection_class(:cloud_networks))
        gateway_options[:network_id] = network.ems_ref
        if (cloud_subnet_id = params["cloud_subnet_id"]).present?
          subnet = resource_search(cloud_subnet_id, type, collection_class(:cloud_subnets))
          gateway_options[:external_fixed_ips] = [{:subnet_id => subnet.ems_ref}]
        end

        if (enable_snat = params["enable_snat"])
          gateway_options[:enable_snat] = enable_snat
        end
      end
      options
    end

    private def options_by_ems_id
      ems = resource_search(params["ems_id"], :ext_management_systems, ExtManagementSystem)
      klass = NetworkRouter.class_by_ems(ems)

      raise BadRequestError, "No Cloud Network support for - #{ems.class}" unless defined?(ems.class::NetworkRouter)

      raise BadRequestError, "No DDF specified for - #{klass}" unless klass.supports?(:create)

      render_options(:cloud_networks, :form_schema => klass.params_for_create(ems))
    end

    private def options_by_id
      network_router = resource_search(params["id"], :network_routers, NetworkRouter)
      render_options(:network_routers, :form_schema => network_router.params_for_update)
    end
  end
end
