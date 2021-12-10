package uk.ac.cam.lib.cudl.awslambda.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.beans.ConstructorProperties;
import java.util.List;

/**
 * This is an incomplete implementation, just include info for editing collection types.
 * TODO extend.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class UI {

    @JsonProperty("@type")
    private final String type;

    @JsonProperty("theme-name")
    private final String theme_name;

    @JsonProperty("theme-data")
    private final UIThemeData theme_data;


    @ConstructorProperties({"@type", "theme-name", "theme-data"})
    @JsonCreator(mode = JsonCreator.Mode.PROPERTIES)
    public UI(@JsonProperty("@type") String type,
              @JsonProperty("theme-name") String theme_name,
              @JsonProperty("theme-data") UIThemeData theme_data) {
        this.type = type;
        this.theme_name = theme_name;
        this.theme_data = theme_data;

    }

    @JsonProperty("@type")
    public String getType() {
        return type;
    }

    @JsonProperty("theme-name")
    public String getThemeName() {
        return theme_name;
    }

    @JsonProperty("theme-data")
    public UIThemeData getThemeData() {
        return theme_data;
    }

    @Override
    public String toString() {
        StringBuffer sb = new StringBuffer();
        sb.append("class Dataset {\n");
        sb.append("    @type: ").append(toIndentedString(type)).append("\n");
        sb.append("    theme-name: ").append(toIndentedString(theme_name)).append("\n");
        sb.append("    theme-data: ").append(toIndentedString(theme_data)).append("\n");
        sb.append("}");
        return sb.toString();
    }

    /**
     * Convert the given object to string with each line indented by 4 spaces
     * (except the first line).
     */
    private String toIndentedString(Object o) {
        if (o == null) {
            return "null";
        }
        return o.toString().replace("\n", "\n    ");
    }
}
