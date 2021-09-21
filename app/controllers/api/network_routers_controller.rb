module Api
  class NetworkRoutersController < BaseController
    include Subcollections::Tags

    def create_resource(_type, _id = nil, data = {})
      ems = ExtManagementSystem.find(data['ems_id'])
      klass = NetworkRouter.class_by_ems(ems)
      raise BadRequestError, "Create network router for Provider #{ems.name}: #{klass.unsupported_reason(:create)}" unless klass.supports?(:create)

      task_id = ems.create_network_router_queue(User.current_userid, data.deep_symbolize_keys)
      action_result(true, "Creating Network Router #{data['name']} for Provider: #{ems.name}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def edit_resource(type, id, data)
      network_router = resource_search(id, type, collection_class(:network_routers))
      raise BadRequestError, "Update for #{network_router_ident(network_router)}: #{network_router.unsupported_reason(:update)}" unless network_router.supports?(:update)

      task_id = network_router.update_network_router_queue(User.current_userid, data.deep_symbolize_keys)
      action_result(true, "Updating #{network_router_ident(network_router)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def delete_resource(type, id, _data = {})
      delete_action_handler do
        network_router = resource_search(id, type, collection_class(:network_routers))
        raise "Delete not supported for #{network_router_ident(network_router)}" unless network_router.respond_to?(:delete_network_router_queue)

        task_id = network_router.delete_network_router_queue(User.current_userid)
        action_result(true, "Deleting #{network_router_ident(network_router)}", :task_id => task_id)
      end
    end

    private def options_by_ems_id
      ems = resource_search(params["ems_id"], :ext_management_systems, ExtManagementSystem)
      klass = NetworkRouter.class_by_ems(ems)

      raise BadRequestError, "No Cloud Network support for - #{ems.class}" unless defined?(ems.class::NetworkRouter)

      raise BadRequestError, "No DDF specified for - #{klass}" unless klass.supports?(:create)

      render_options(:cloud_networks, :form_schema => klass.params_for_create(ems, params["cn_id"]))
    end

    private def options_by_id
      network_router = resource_search(params["id"], :network_routers, NetworkRouter)
      render_options(:network_routers, :form_schema => network_router.params_for_update)
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

    def network_router_ident(network_router)
      "Network Router id:#{network_router.id} name: '#{network_router.name}'"
    end
  end
end
