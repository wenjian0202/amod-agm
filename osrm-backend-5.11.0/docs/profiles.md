# OSRM profiles
OSRM supports "profiles". Profiles representing routing behavior for different transport modes like car, bike and foot. You can also create profiles for variations like a fastest/shortest car profile or fastest/safest/greenest bicycles profile.

 A profile describes whether or not it's possible to route along a particular type of way, whether we can pass a particular node, and  how quickly we'll be traveling when we do. This feeds into the way the routing graph is created and thus influences the output routes.

## Available profiles
Out-of-the-box OSRM comes with profiles for car, bicycle and foot. You can easily modify these or create new ones if you like.

Profiles have a 'lua' extension, and are places in 'profiles' directory.

When running OSRM preprocessing commands you specify the profile with the --profile (or the shorthand -p) option, for example:

`osrm-extract --profile ../profiles/car.lua planet-latest.osm.pbf`

## Processing flow
It's important to understand that profiles are used when preprocessing the OSM data, NOT at query time when routes are computed.

This means that after modifying a profile **you will need to extract, contract and reload the data again** and to see changes in the routing results. See [Processing Flow](https://github.com/Project-OSRM/osrm-backend/wiki/Processing-Flow) for more.

## Profiles are written in LUA
Profiles are not just configuration files. They are scripts written in the [LUA scripting language](http://www.lua.org). The reason for this is that OpenStreetMap data is complex, and it's not possible to simply define tag mappings. LUA scripting offers a powerful way to handle all the possible tag combinations found in OpenStreetMap nodes and ways.

## Basic structure of profiles
A profile will process every node and way in the OSM input data to determine what ways are routable in which direction, at what speed, etc.

A profile will typically:

- Define api version (required)
- Require library files (optional)
- Define setup function (required)
- Define process functions (some are required)
- Return functions table (required)

A profile can also define various local functions it needs.

Looking at [car.lua](../profiles/car.lua) as an example, at the top of the file the api version is defined and then required library files are included.

Then follows the `setup` functions, which is called once when the profile is loaded. It returns a big hash table of configurations, specifying things like what speed to use for different way types. The configurations are used later in the various processing functions. Many adjustments can be done just be modifying this configuration table.

The setup function is also where you can do other setup, like loading elevation data source if you want to consider that when processing ways.

Then comes the `process_node` and `process_way` functions, which are called for each OSM node and way when extracting OpenStreetMap data with `osrm-extract`.

The `process_turn` function processes every possible turn in the network, and sets a penalty depending on the angle and turn of the movement.

Profiles can also define a `process_segment` function to handle differences in speed along an OSM way, for example to handle elevation. As you can see, this is not currently used in the car profile.

At the end of the file, a table if returned with references to the setup and processing functions the profile has defined.

## Understanding speed, weight and rate 
When computing a route from A to B there can be different measure of what is the best route. That's why there's a need for different profiles.

Because speeds very on different types of roads, the shortest and the fastest route are typically different. But there are many other possible preferences. For example a user might prefer a bicycle route that follow parks or other green areas, even though both duration and distance are a bit longer.

To handle this, OSRM doesn't simply choose the ways with the highest speed. Instead it uses the concept of `weight` and `rate`. The rate is an abstract measure that you can assign to  ways as you like to make some ways preferable to others. Routing will prefer ways with high rate.

The weight of a way normally computed as length / rate. The weight can be thought of as the resistance or cost when passing the way. Routing will prefer ways with low weight.

You can also set the weight of a way to a fixed value, In this case it's not calculated based on the length or rate, and the rate is ignored.

You should set the speed to you best estimate of the actual speed that will be used on a particular way. This will result in the best estimated travel times.

If you want to prefer certain ways due to other factors than the speed, adjust the rate accordingly. If you adjust the speed, the time time estimation will be skewed.

If you set the same rate on all ways, the result will be shortest path routing.
If you set rate = speed on all ways, the result will be fastest path routing.
If you want to prioritize certain street, increase the rate on these.

## Elements
### api_version
A profile should set api_version at the top of your profile. This is done to ensure that older profiles are still supported when the api changes. If api_version is not defined, 0 will be assumed. The current api version is 2.

### Library files
The folder [profiles/lib/](../profiles/lib/) contains LUA library files for handling many common processing tasks.

File              | Notes
------------------|------------------------------
way_handlers.lua  | Functions for processing way tags
tags.lua          | Functions for general parsing of OSM tags
set.lua           | Defines the Set helper for handling sets of values
sequence.lua      | Defines the Sequence helper for handling sequences of values
access.lua        | Function for finding relevant access tags
destination.lua   | Function for finding relevant destination tags
destination.lua   | Function for determining maximum speed
guidance.lua      | Function for processing guidance attributes

They all return a table of functions when you use `require` to load them. You can either store this table and reference it's functions later, of if you need only a single you can store that directly.

### setup()
The `setup` function is called once when the profile is loaded and must return a table of configurations. It's also where you can do other global setup, like loading data sources that are used during processing.

Note that processing of data is parallelized and several unconnected LUA interpreters will be running at the same time. The `setup` function will be called once for each. Each LUA iinterpreter will have it's own set of globals.

The following global properties can be set under `properties` in the hash you return in the `setup` function: 

Attribute                            | Type     | Notes
-------------------------------------|----------|----------------------------------------------------------------------------
weight_name                          | String   | Name used in output for the routing weight property (default `'duration'`)
weight_precision                     | Unsigned | Decimal precision of edge weights (default `1`)
left_hand_driving                    | Boolean  | Are vehicles assumed to drive on the left? (used in guidance, default `false`)
use_turn_restrictions                | Boolean  | Are turn instructions followed? (default `false`)
continue_straight_at_waypoint        | Boolean  | Must the route continue straight on at a via point, or are U-turns allowed? (default `true`)
max_speed_for_map_matching           | Float    | Maximum vehicle speed to be assumed in matching (in m/s)
max_turn_weight                      | Float    | Maximum turn penalty weight
force_split_edges                    | Boolean  | True value forces a split of forward and backward edges of extracted ways and guarantees that `process_segment` will be called for all segments (default `false`)

### process_node(profile, node, result)
Process an OSM node to determine whether this node is a barrier or can be passed and whether passing it incurs a delay.

Argument | Description
---------|-------------------------------------------------------
profile  | The configuration table you returned in `setup`.
node     | The input node to process (read-only).
result   | The output that you will modify.

The following attributes can be set on `result`:

Attribute       | Type    | Notes
----------------|---------|---------------------------------------------------------
barrier         | Boolean | Is it an impassable barrier?
traffic_lights  | Boolean | Is it a traffic light (incurs delay in `process_turn`)?

## process_way(profile, way, result)
Given an OpenStreetMap way, the `process_way` function will either return nothing (meaning we are not going to route over this way at all), or it will set up a result hash.

Argument | Description
---------|-------------------------------------------------------
profile  | The configuration table you returned in `setup`.
node     | The input way to process (read-only).
result   | The output that you will modify.

Importantly it will set `result.forward_mode` and `result.backward_mode` to indicate the travel mode in each direction, as well as set `result.forward_speed` and `result.backward_speed` to integer values representing the speed for traversing the way.

It will also set a number of other attributes on `result`.

Using the power of the scripting language you wouldn't typically see something as simple as a `result.forward_speed = 20` line within the `process_way` function. Instead `process_way` will examine the tag set on the way, process this information in various ways, calling other local functions and referencing the configuration in `profile`, etc, before arriving at the result.

The following attributes can be set on the result in `process_way`:

Attribute                               | Type     | Notes
----------------------------------------|----------|--------------------------------------------------------------------------
forward_speed                           | Float    | Speed on this way in km/h. Mandatory.
backward_speed                          | Float    |  "   "
forward_rate                            | Float    | Routing weight, expressed as meters/*weight* (e.g. for a fastest-route weighting, you would want this to be meters/second, so set it to forward_speed/3.6)
backward_rate                           | Float    |  "   "
forward_mode                            | Enum     | Mode of travel (e.g. `car`, `ferry`). Mandatory. Defined in `include/extractor/travel_mode.hpp`.
backward_mode                           | Enum     |  "   "
forward_classes                         | Table    | Mark this way as being of a specific class, e.g. `result.classes["toll"] = true`. This will be exposed in the API as `classes` on each `RouteStep`.
backward_classes                        | Table    |  "   "
duration                                | Float    | Alternative setter for duration of the whole way in both directions
weight                                  | Float    | Alternative setter for weight of the whole way in both directions
turn_lanes_forward                      | String   | Directions for individual lanes (normalized OSM `turn:lanes` value)
turn_lanes_backward                     | String   |  "   "
forward_restricted                      | Boolean  | Is this a restricted access road? (e.g. private, or deliveries only; used to enable high turn penalty, so that way is only chosen for start/end of route)
backward_restricted                     | Boolean  |  "   "
is_startpoint                           | Boolean  | Can a journey start on this way? (e.g. ferry; if `false`, prevents snapping the start point to this way)
roundabout                              | Boolean  | Is this part of a roundabout?
circular                                | Boolean  | Is this part of a non-roundabout circular junction?
name                                    | String   | Name of the way
ref                                     | String   | Road number
destinations                            | String   | The road's destinations
exits                                   | String   | The ramp's exit numbers or names
pronunciation                           | String   | Name pronunciation
road_classification.motorway_class      | Boolean  | Guidance: way is a motorway
road_classification.link_class          | Boolean  | Guidance: way is a slip/link road
road_classification.road_priority_class | Enum     | Guidance: order in priority list. Defined in `include/extractor/guidance/road_classification.hpp`
road_classification.may_be_ignored      | Boolean  | Guidance: way is non-highway
road_classification.num_lanes           | Unsigned | Guidance: total number of lanes in way

### process_segment(profile, segment)
The `process_segment` function is called for every segment of OSM ways. A segment is a straight line between two OSM nodes. 

On OpenStreetMap way cannot have different tags on different parts of a way. Instead you would split the way into several smaller ways. However many ways are long. For example, many ways pass hills without any change in tags. 

Processing each segment of an OSM way makes it possible to have different speeds on different parts of a way based on external data like data about elevation, pollution, noise or scenic value and adjust weight and duration of the segment.

In the `process_segment` you don't have access to OSM tags. Instead you use the geographical location of the start and end point of the way to lookup other data source, like elevation data. See [rasterbot.lua](../profiles/rasterbot.lua) for an example.

The following attributes can be read and set on the result in `process_segment`:

Attribute          | Read/write? | Type    | Notes
-------------------|-------------|---------|----------------------------------------
source.lon         | Read        | Float   | Co-ordinates of segment start
source.lat         | Read        | Float   |  "   "
target.lon         | Read        | Float   | Co-ordinates of segment end
target.lat         | Read        | Float   |  "   "
target.distance    | Read        | Float   | Length of segment
weight             | Read/write  | Float   | Routing weight for this segment
duration           | Read/write  | Float   | Duration for this segment

### process_turn(profile, turn)
The `process_turn` function is called for every possible turn in the network. Based on the angle and type of turn you assign the weight and duration of the movement.

The following attributes can be read and set on the result in `process_turn`:

Attribute          | Read/write? | Type    | Notes
-------------------|-------------|---------|------------------------------------------------------
direction_modifier | Read        | Enum    | Geometry of turn. Defined in `include/extractor/guidance/turn_instruction.hpp`
turn_type          | Read        | Enum    | Priority of turn. Defined in `include/extractor/guidance/turn_instruction.hpp`
has_traffic_light  | Read        | Boolean | Is a traffic light present at this turn?
source_restricted  | Read        | Boolean | Is it from a restricted access road? (See definition in `process_way`)
target_restricted  | Read        | Boolean | Is it to a restricted access road? (See definition in `process_way`)
angle              | Read        | Float   | Angle of turn in degrees (`0-360`: `0`=u-turn, `180`=straight on)
duration           | Read/write  | Float   | Penalty to be applied for this turn (duration in deciseconds)
weight             | Read/write  | Float   | Penalty to be applied for this turn (routing weight)

## Guidance
The guidance parameters in profiles are currently a work in progress. They can and will change.
Please be aware of this when using guidance configuration possibilities.

Guidance uses road classes to decide on when/if to emit specific instructions and to discover which road is obvious when following a route.
Classification uses three flags and a priority-category.
The flags indicate whether a road is a motorway (required for on/off ramps), a link type (the ramps itself, if also a motorway) and whether a road may be omitted in considerations (is considered purely for connectivity).
The priority-category influences the decision which road is considered the obvious choice and which roads can be seen as fork.
Forks can be emitted between roads of similar priority category only. Obvious choices follow a major priority road, if the priority difference is large.

### Using raster data
OSRM has build-in support for loading an interpolating raster data in ASCII format. This can be used e.g. for factoring in elevation when computing routes.

Use `raster:load()` in your `setup` function to load data and store the source in your configuration hash:

```lua
function setup()
  return {
    raster_source = raster:load(
      "rastersource.asc",  -- file to load
      0,    -- longitude min
      0.1,  -- longitude max
      0,    -- latitude min
      0.1,  -- latitude max
      5,    -- number of rows
      4     -- number of columns
    )
  }
end
```

The input data must an ASCII file with rows of integers. e.g.:

```
0  0  0   0
0  0  0   250
0  0  250 500
0  0  0   250
0  0  0   0
```

In your `segment_function` you can then access the raster source and use `raster:query()` to query to find the nearest data point, or `raster:interpolate()` to interpolate a value based on nearby data points.

You must check whether the result is valid before use it.

Example:

```lua
function process_segment (profile, segment)
  local sourceData = raster:query(profile.raster_source, segment.source.lon, segment.source.lat)
  local targetData = raster:query(profile.raster_source, segment.target.lon, segment.target.lat)
  
  local invalid = sourceData.invalid_data()
  if sourceData.datum ~= invalid and targetData.datum ~= invalid then
      -- use values to adjust weight and duration
    [...]
end
```

See [rasterbot.lua](../profiles/rasterbot.lua) and [rasterbotinterp.lua](../profiles/rasterbotinterp.lua) for examples.

### Helper functions
There are a few helper functions defined in the global scope that profiles can use:

durationIsValid
parseDuration
trimLaneString
applyAccessTokens
canonicalizeStringList