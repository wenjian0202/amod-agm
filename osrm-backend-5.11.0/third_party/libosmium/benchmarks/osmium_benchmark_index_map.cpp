/*

  The code in this file is released into the Public Domain.

*/

#include <cstdlib>
#include <iostream>
#include <string>

#include <osmium/index/map/all.hpp>
#include <osmium/handler/node_locations_for_ways.hpp>
#include <osmium/visitor.hpp>

#include <osmium/io/any_input.hpp>
#include <osmium/handler.hpp>

using index_type = osmium::index::map::Map<osmium::unsigned_object_id_type, osmium::Location>;

using location_handler_type = osmium::handler::NodeLocationsForWays<index_type>;

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " OSMFILE FORMAT\n";
        std::exit(1);
    }

    const std::string input_filename{argv[1]};
    const std::string location_store{argv[2]};

    osmium::io::Reader reader{input_filename};

    const auto& map_factory = osmium::index::MapFactory<osmium::unsigned_object_id_type, osmium::Location>::instance();
    std::unique_ptr<index_type> index = map_factory.create_map(location_store);
    location_handler_type location_handler{*index};
    location_handler.ignore_errors();

    osmium::apply(reader, location_handler);
    reader.close();
}
